package main

import (
	"context"
	"flag"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strconv"
	"strings"
	"sync/atomic"
	"time"
)

// defaults
const (
	defaultRequestPort = 9000
	defaultGpuPorts    = "8000,8001,8002,8003"
	defaultNode        = "localhost" // or gpu005.service
)

// Load balancer for VLLM multi-GPU setup
// run as a service to accept incoming requests and distribute them across available GPUs
func main() {

	// get flags from command line
	// list of ports, comma separated, corresponding to available GPUs
	ports := flag.String("gpu_ports", defaultGpuPorts, "Comma separated list of GPU ports")
	// gpu node (hostname of the machine where the GPUs are located, e.g., localhost or gpu005.service)
	// yes, this code assumes that we have only one node with multiple GPUs...
	// if that ever changes, the code would need to be updated to handle multiple nodes.
	node := flag.String("node", defaultNode, "GPU node hostname")
	// port for incoming requests
	requestPort := flag.Uint("request_port", defaultRequestPort, "Port for incoming requests")
	flag.Parse()

	// parse GPU ports and node from command line flags
	gpuPorts := strings.Split(*ports, ",")
	if len(gpuPorts) == 0 {
		log.Fatalf("No GPU ports specified")
	}
	// verify that GPU ports are valid integers
	for _, port := range gpuPorts {
		if _, err := strconv.Atoi(port); err != nil {
			log.Fatalf("Invalid GPU port: %s", port)
		}
	}

	log.Printf("Starting load balancer on port %d with GPU ports: %v", *requestPort, gpuPorts)
	// start the HTTP server with the load balancer as the handler
	if err := http.ListenAndServe(":"+strconv.Itoa(int(*requestPort)), NewLoadBalancer(gpuPorts, *node)); err != nil {
		panic(err)
	}

}

// LoadBalancer represents the load balancer that distributes requests across multiple GPU backends.
type LoadBalancer struct {
	backends []*Backend
	current  atomic.Uint64
}

// Backend represents a single GPU backend with its URL, reverse proxy, and active status.
type Backend struct {
	Url          *url.URL
	ReverseProxy *httputil.ReverseProxy
	Active       atomic.Bool
}

// NewLoadBalancer creates a new LoadBalancer instance with the given ports and node.
func NewLoadBalancer(ports []string, node string) *LoadBalancer {
	backends := make([]*Backend, len(ports))

	for i, port := range ports {
		target := &url.URL{
			Scheme: "http",
			Host:   node + ":" + port,
		}
		proxy := httputil.NewSingleHostReverseProxy(target)
		proxy.FlushInterval = -1 // no buffering

		backends[i] = &Backend{
			Url:          target,
			ReverseProxy: proxy,
			Active:       atomic.Bool{},
		}
		backends[i].Active.Store(true)
	}
	lb := &LoadBalancer{
		backends: backends,
		current:  atomic.Uint64{},
	}

	go lb.startHealthCheck()

	return lb
}

// GetNextProxy returns the next reverse proxy in a round-robin fashion.
func (lb *LoadBalancer) GetNextProxy() *httputil.ReverseProxy {
	if len(lb.backends) == 0 {
		return nil
	}

	idx := lb.current.Add(1) % uint64(len(lb.backends))
	return lb.backends[idx].ReverseProxy
}

// ServeHTTP handles incoming HTTP requests and forwards them to the next available GPU backend.
func (lb *LoadBalancer) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	proxy := lb.GetNextProxy()

	if proxy == nil {
		http.Error(w, "No available proxies", http.StatusServiceUnavailable)
		return
	}

	proxy.ServeHTTP(w, r)
}

// startHealthCheck periodically checks the health of each GPU backend and updates their active status.
func (lb *LoadBalancer) startHealthCheck() {
	ticker := time.NewTicker(5 * time.Second)

	client := &http.Client{
		Timeout: 5 * time.Second,
	}
	for range ticker.C {
		for _, backend := range lb.backends {
			healthCheckURL := backend.Url.String() + "/health"
			req, _ := http.NewRequestWithContext(context.Background(), "GET", healthCheckURL, nil)
			resp, err := client.Do(req)

			isAlive := err == nil && resp.StatusCode == http.StatusOK
			if resp != nil && resp.Body != nil {
				resp.Body.Close()
			}

			// Update the active status of the backend and log any changes.
			oldStatus := backend.Active.Swap(isAlive)
			if oldStatus != isAlive {
				if isAlive {
					log.Printf("🟢 GPU-Instanz wieder ONLINE: %s", backend.Url.String())
				} else {
					log.Printf("🔴 GPU-Instanz OFFLINE / CRASHED: %s", backend.Url.String())
				}
			}
		}
	}
}

package main
import (
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
	"sync/atomic"
	"time"
	"context"
)

// Load balancer for VLLM multi-GPU setup
// run as a service to accept incoming requests and distribute them across available GPUs
func main() {


	// cmd line 
	// list of ports, comma separated, corresponding to available GPUs (TODO parse from command line)
	ports := "8000,8001,8002,8003" // example ports for 4 GPUs
	// gpu node (TODO parse from command line)
	node := "localhost" // or the hostname of the GPU node
	// incoming requests port
	requestPort := "9000" // example port for incoming requests (TODO parse from command line)
	// load balancer initialization (TODO implement)

	gpuPorts := strings.Split(ports, ",")

	log.Printf("Starting load balancer on port %s with GPU ports: %v", requestPort, gpuPorts)
	
	if err := http.ListenAndServe(":"+requestPort, NewLoadBalancer(gpuPorts, node)); err != nil {
		panic(err)
	}

}

type LoadBalancer struct {
	backends []*Backend
	current atomic.Uint64
}

type Backend struct {
	Url *url.URL
	ReverseProxy *httputil.ReverseProxy
	Active atomic.Bool
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
		current: atomic.Uint64{},
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

func (lb *LoadBalancer) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	proxy := lb.GetNextProxy()
	
	if proxy == nil {
		http.Error(w, "No available proxies", http.StatusServiceUnavailable)
		return
	}
	
	proxy.ServeHTTP(w, r)
}

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

			// Statusänderung erkennen und loggen
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


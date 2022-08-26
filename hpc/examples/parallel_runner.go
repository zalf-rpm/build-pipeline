package main

import (
	"flag"
	"time"
)

func main() {

	// use a number of goroutines to do write a message and sleep for a while

	// read command line arguments
	// number of tasks
	cores := flag.Int("cores", 4, "number of cores")
	taskId := flag.Int("task", 0, "task id")
	flag.Parse()

	// create a channel to communicate with the other tasks
	outChan := make(chan bool)
	for i := 0; i < *cores; i++ {
		go func(index, taskId int, outChan chan bool) {

			println("Task ", taskId, " is running on core ", index)
			// sleep for a while
			time.Sleep(time.Second * 5)
			// send a message to the channel
			outChan <- true
		}(i, *taskId, outChan)
	}

	// wait for all goroutines to finish
	finished := 0
	for finished < *cores {
		<-outChan
		finished++
	}
}

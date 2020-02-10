package main

import (
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
)

func main() {

	argsWithoutExe := os.Args[1:]

	if len(argsWithoutExe) == 0 {
		log.Fatal("Missing argurment: SLURM_NODE_LIST")
	}
	nodelist := argsWithoutExe[0]

	tokens := strings.Split(nodelist, "[")
	nodename := tokens[0]
	var finalList []string
	rest := tokens[1]
	rest = strings.Trim(rest, "]")
	tokens = strings.Split(rest, ",")
	for _, token := range tokens {
		if strings.Contains(token, "-") {
			numbers := strings.SplitN(token, "-", 2)
			val1, err := strconv.ParseInt(numbers[0], 10, 64)
			if err != nil {
				log.Fatal("Failed to parse node list")
			}
			val2, err := strconv.ParseInt(numbers[1], 10, 64)
			if err != nil {
				log.Fatal("Failed to parse node list")
			}
			for i := val1; i <= val2; i++ {
				finalList = append(finalList, fmt.Sprintf("%s%03d", nodename, i))
			}
		} else {
			finalList = append(finalList, nodename+token)
		}
	}
	fmt.Print(strings.Join(finalList, ","))
}

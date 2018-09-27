package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
)

const dockerAPIURL string = "https://hub.docker.com"

// fetch docker tags, return them as json format string
// baseurl = e.g. https://hub.docker.com
// project = <user/organisation>/<image name>
func fetchDockerTags(project string, baseurl string) (string, error) {

	url := fmt.Sprintf("%s/v2/repositories/%s/tags", baseurl, project)
	client := &http.Client{}
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	response, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer response.Body.Close()

	// get tags from result
	type Tags struct {
		Name string `json:"name"`
	}
	type ImageList struct {
		Result []Tags `json:"results"`
	}
	var content ImageList
	if err = json.NewDecoder(response.Body).Decode(&content); err != nil {
		return "", err
	}

	var tags []string
	for _, val := range content.Result {
		tags = append(tags, val.Name)
	}

	// export to rundeck json format
	jsonText, err := json.Marshal(tags)
	if err != nil {
		return "", err
	}
	resultTags := string(jsonText)

	return resultTags, err
}

func rundeckVarHandler(w http.ResponseWriter, r *http.Request) {
	requestType := r.URL.Path[len("/rundeckvar/"):]
	w.Header().Set("Content-Type", "application/json")
	if strings.HasPrefix(requestType, "dockertags/") {
		dockerProject := r.URL.Path[len("/rundeckvar/dockertags/"):]
		taglist, err := fetchDockerTags(dockerProject, dockerAPIURL)
		if err != nil {
			fmt.Fprintf(w, `["ERROR"]`)
			return
		}
		fmt.Fprintf(w, taglist)
		return
	}
	fmt.Fprintf(w, `["INVALID PARAMETER"]`)
}

func main() {
	http.HandleFunc("/rundeckvar/", rundeckVarHandler)
	log.Fatal(http.ListenAndServe(":6080", nil))
}

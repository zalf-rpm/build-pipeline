package main

import "encoding/xml"

// ProjectData decription
type ProjectData struct {
	XMLName          xml.Name   `xml:"projectdata"`
	ProjectIntefaces Interfaces `xml:"interfaces"`
}

// Interfaces for simplace
type Interfaces struct {
	XMLName    xml.Name       `xml:"interfaces"`
	Interfaces []SimInterface `xml:"interface"`
}

// SimInterface decription
type SimInterface struct {
	XMLName  xml.Name `xml:"interface"`
	ID       string   `xml:"id,attr"`
	FileType string   `xml:"type,attr"`
	Poolsize int      `xml:"poolsize"`
	Divider  string   `xml:"divider"`
	Filename string   `xml:"filename"`
}

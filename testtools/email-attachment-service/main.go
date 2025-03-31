package main

import (
	"fmt"
	"log"
	"os"
	"time"

	"golang.org/x/sys/windows/svc"
	"golang.org/x/sys/windows/svc/debug"
)

func main() {

	f, err := os.OpenFile("debug.log", os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666)
	if err != nil {
		log.Fatalln(fmt.Errorf("error opening file: %v", err))
	}
	defer f.Close()

	log.SetOutput(f)

	// read the configuration file
	config, err := LoadConfig("config.yaml")
	if err != nil {
		log.Fatalf("Error loading configuration: %v", err)
	}

	// validate the configuration
	if err := config.Validate(); err != nil {
		log.Fatalf("Invalid configuration: %v", err)
	}

	// create the email config
	eConf := NewEmailConfig(config)
	emailCient := NewEmailClient(config)

	runService("EmailAttachmentDownload", eConf, emailCient, false) //change to true to run in debug mode
}

func runService(name string, eConf *EmailConfig, emailCient *EmailClient, isDebug bool) {

	service := &emailAttachmentService{
		emailClient: emailCient,
		emailConfig: eConf,
	}
	if isDebug {
		err := debug.Run(name, service)
		if err != nil {
			log.Fatalln("Error running service in debug mode.")
		}
	} else {
		err := svc.Run(name, service)
		if err != nil {
			log.Fatalln("Error running service in Service Control mode.")
		}
	}
}

const cmdsAccepted = svc.AcceptStop | svc.AcceptShutdown | svc.AcceptPauseAndContinue

// implement the service interface to as a windows service
type emailAttachmentService struct {
	emailClient *EmailClient
	emailConfig *EmailConfig
}

func (eas *emailAttachmentService) Execute(args []string, r <-chan svc.ChangeRequest, s chan<- svc.Status) (svcSpecificEC bool, exitCode uint32) {
	// Service start
	svcSpecificEC = false
	exitCode = 0
	svcStatus := svc.Status{State: svc.StartPending}
	s <- svcStatus
	svcStatus.State = svc.Running
	svcStatus.Accepts = cmdsAccepted
	s <- svcStatus

	tick := time.Tick(30 * time.Second)
	// Service loop
	for {
		select {
		case <-tick:
			// Check for new emails
			log.Print("Check for new emails...")
			if err := eas.emailClient.CheckForNewEmails(eas.emailConfig); err != nil {
				log.Printf("Error checking emails: %v", err)
			}

		case c := <-r:
			switch c.Cmd {
			case svc.Interrogate:
				s <- c.CurrentStatus
			case svc.Stop, svc.Shutdown:
				log.Print("Shutting service...!")
				svcStatus.State = svc.StopPending
				s <- svcStatus
				return
			case svc.Pause:
				svcStatus.State = svc.Paused
				svcStatus.Accepts = cmdsAccepted
				s <- svcStatus
			case svc.Continue:
				svcStatus.State = svc.Running
				svcStatus.Accepts = cmdsAccepted
				s <- svcStatus
			default:
				log.Printf("Unexpected service control request #%d", c)
				continue
			}
		}
	}
}

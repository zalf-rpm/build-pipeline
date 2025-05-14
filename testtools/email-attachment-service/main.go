package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	"golang.org/x/sys/windows/svc"
	"golang.org/x/sys/windows/svc/debug"
)

func main() {

	// parse command line arguments
	debug := flag.Bool("debug", false, "Run in debug mode")
	flag.Parse()

	// Set up logging to file
	// rename existing log file
	if _, err := os.Stat("debug.log"); err == nil {
		// with date and time
		newFileName := fmt.Sprintf("debug_%s.log", time.Now().Format("2006-01-02_15-04-05"))
		err := os.Rename("debug.log", newFileName)
		if err != nil {
			log.Fatalln(fmt.Errorf("error renaming file: %v", err))
		}
	}
	f, err := os.OpenFile("debug.log", os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666)
	if err != nil {
		log.Fatalln(fmt.Errorf("error opening file: %v", err))
	}
	defer f.Close()

	// Set up logging to file
	log.SetOutput(f)
	log.SetPrefix("EmailAttachmentService: ")
	log.SetFlags(log.Ldate | log.Ltime | log.Lshortfile)
	log.Println("Starting Email Attachment Service...")

	// read the configuration file
	eConf, emailCient, err := loadAndValidateEmailSettings()
	if err != nil {
		log.Fatalln(fmt.Errorf("error loading configuration: %v", err))
	}

	runService("EmailAttachmentDownload", eConf, emailCient, *debug) //change to true to run in debug mode
}

func loadAndValidateEmailSettings() (*EmailConfig, *EmailClient, error) {
	config, err := LoadConfig("config.yaml")
	if err != nil {
		return nil, nil, fmt.Errorf("error loading config.yml: %v", err)
	}

	// validate the configuration
	if err := config.Validate(); err != nil {
		return nil, nil, fmt.Errorf("config validation failed: %v", err)
	}

	// create the email config
	eConf := NewEmailConfig(config)
	emailCient, err := NewEmailClient(config)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to create email client: %v", err)
	}
	return eConf, emailCient, nil
}

func runService(name string, eConf *EmailConfig, emailCient *EmailClient, isDebug bool) {

	service := &emailAttachmentService{
		emailClient:     emailCient,
		emailConfig:     eConf,
		checkupInterval: time.Duration(eConf.CheckupInterval) * time.Hour,
	}
	if isDebug {
		service.checkupInterval = 30 * time.Second
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
	emailClient     *EmailClient
	emailConfig     *EmailConfig
	checkupInterval time.Duration
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

	// initial email check, in verbose mode, next check will happen after the interval
	log.Print("Initial Check for new emails...")
	if err := eas.emailClient.CheckForNewEmails(eas.emailConfig, true); err != nil {
		log.Printf("Error checking emails: %v", err)
	}
	// Set up a ticker for the checkup interval
	tick := time.Tick(eas.checkupInterval)

	// Service loop
	for {
		select {
		case <-tick:
			// Check for new emails
			log.Print("Check for new emails...")
			if err := eas.emailClient.CheckForNewEmails(eas.emailConfig, eas.emailConfig.Verbose); err != nil {
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
				// reload the configuration
				log.Print("Reloading configuration...")
				eConf, emailCient, err := loadAndValidateEmailSettings()
				if err != nil {
					log.Printf("Error reloading configuration: %v", err)
				} else {
					log.Print("Configuration reloaded successfully.")
					eas.emailClient = emailCient
					eas.emailConfig = eConf
				}
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

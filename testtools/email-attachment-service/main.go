package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"golang.org/x/sys/windows/svc"
	"golang.org/x/sys/windows/svc/debug"
)

func main() {

	// parse command line arguments
	debug := flag.Bool("debug", false, "Run in debug mode")
	flag.Parse()

	// enable event tracing for the service
	//workingDirectory, err := os.Getwd()
	// create a directory for the log file
	executablePath, err := os.Executable()
	if err != nil {
		log.Fatalln(fmt.Errorf("error getting executable path: %v", err))
	}
	workingDirectory := filepath.Dir(executablePath)

	if err != nil {
		log.Fatalln(fmt.Errorf("error getting current directory: %v", err))
	}

	// Set up logging to file
	// check if logs directory exists, if not create it
	logDir := fmt.Sprintf("%s\\logs", workingDirectory)
	if _, err := os.Stat(logDir); os.IsNotExist(err) {
		err := os.Mkdir(logDir, 0755)
		if err != nil {
			log.Fatalln(fmt.Errorf("error creating logs directory: %v", err))
		}
	}

	logPath := fmt.Sprintf("%s\\debug.log", logDir)
	// rename existing log file
	if _, err := os.Stat(logPath); err == nil {
		// with date and time
		newFileName := fmt.Sprintf("%s\\debug_%s.log", logDir, time.Now().Format("2006-01-02_15-04-05"))
		err := os.Rename(logPath, newFileName)
		if err != nil {
			log.Fatalln(fmt.Errorf("error renaming file: %v", err))
		}
	}

	f, err := os.OpenFile(logPath, os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666)
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
		log.Printf("error loading configuration: %v", err)
	}

	runService("email-attachment-service", eConf, emailCient, *debug) //change to true to run in debug mode

}

func loadAndValidateEmailSettings() (*EmailConfig, *EmailClient, error) {
	// find config.yaml in executable directory
	executablePath, err := os.Executable()
	if err != nil {
		return nil, nil, fmt.Errorf("error getting executable path: %v", err)
	}
	executableDir := filepath.Dir(executablePath)
	configPath := filepath.Join(executableDir, "config.yaml")

	config, err := LoadConfig(configPath)
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

	checkup := time.Duration(1) * time.Hour
	configValid := false
	if eConf != nil && emailCient != nil {
		checkup = time.Duration(eConf.CheckupInterval) * time.Hour
		configValid = true
	}

	service := &emailAttachmentService{
		emailClient:     emailCient,
		emailConfig:     eConf,
		checkupInterval: checkup,
		configValid:     configValid,
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
	configValid     bool
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
	if eas.configValid {
		log.Print("Initial Check for new emails...")
		if err := eas.emailClient.CheckForNewEmails(eas.emailConfig, true); err != nil {
			log.Printf("Error checking emails: %v", err)
		}
	} else {
		log.Print("Configuration is not valid, skipping initial check.")
	}

	// Set up a ticker for the checkup interval
	tick := time.Tick(eas.checkupInterval)

	// Service loop
	for {
		select {
		case <-tick:
			if !eas.configValid {
				log.Print("Configuration is not valid, skipping check.")
				continue
			}
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
				log.Print("Shutting down service...!")
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
					eas.configValid = false
				} else {
					log.Print("Configuration reloaded successfully.")
					eas.emailClient = emailCient
					eas.emailConfig = eConf
					eas.checkupInterval = time.Duration(eConf.CheckupInterval) * time.Hour
					eas.configValid = true
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

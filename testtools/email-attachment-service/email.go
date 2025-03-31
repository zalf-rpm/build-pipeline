package main

import (
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/emersion/go-imap"
	"github.com/emersion/go-imap/client"
	"github.com/emersion/go-message/mail"
)

// EmailClient represents the email client that connects to the email server.
type EmailClient struct {
	IMAPServer string
	Username   string
	Password   string
}

// NewEmailClient creates a new instance of EmailClient.
func NewEmailClient(config *Config) *EmailClient {
	var username, password string
	var err error
	if config.CredentialKey != "" {
		username, password, err = GetCredential(config.CredentialKey)
		if err != nil {
			log.Fatalf("failed to load credentials: %v", err)
		}
	} else if config.Username == "" || config.Password == "" {
		log.Fatal("creadential_key or username:password are required")
	} else {
		username = config.Username
		password = config.Password
	}
	return &EmailClient{
		IMAPServer: config.EmailServer + ":" + config.Port,
		Username:   username,
		Password:   password,
	}
}

type EmailConfig struct {
	From         string
	SharedFolder string
	DownloadDir  string
	Subject      string
}

func NewEmailConfig(config *Config) *EmailConfig {
	return &EmailConfig{
		From:         config.From,
		SharedFolder: config.SharedFolder,
		DownloadDir:  config.DownloadPath,
		Subject:      config.Subject,
	}
}

// Connect authenticates the client with the email server.
func (ec *EmailClient) Connect() (*client.Client, error) {
	log.Println("Connecting to server...")

	// Connect to server
	c, err := client.DialTLS(ec.IMAPServer, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to server: %v", err)
	}
	log.Println("Connected")

	// Login
	if err := c.Login(ec.Username, ec.Password); err != nil {
		c.LoggedOut()
		return nil, fmt.Errorf("login failed: %v", err)
	}
	log.Println("Logged in")

	return c, nil
}

// CheckForNewEmails searches for new emails and downloads their attachments
func (ec *EmailClient) CheckForNewEmails(eConf *EmailConfig) error {
	c, err := ec.Connect()
	if err != nil {
		return err
	}
	defer c.Logout()

	// Select the mailbox
	mbox, err := c.Select(eConf.SharedFolder, false)
	if err != nil {
		return fmt.Errorf("failed to select mailbox: %v", err)
	}
	log.Printf("Mailbox %s selected, total messages: %d", eConf.SharedFolder, mbox.Messages)

	if mbox.Messages == 0 {
		log.Println("No messages in mailbox")
		return nil
	}

	// Get emails from the last 24 hours
	since := time.Now().Add(-24 * time.Hour)
	criteria := imap.NewSearchCriteria()
	criteria.Since = since
	criteria.Header.Add("From", eConf.From)
	criteria.Header.Add("Subject", eConf.Subject)

	uids, err := c.Search(criteria)
	if err != nil {
		return fmt.Errorf("search failed: %v", err)
	}
	log.Printf("Found %d messages in the last 24 hours", len(uids))

	if len(uids) == 0 {
		return nil
	}

	// Create a sequence set for the UIDs
	seqSet := new(imap.SeqSet)
	seqSet.AddNum(uids...)

	// Get the whole message body
	section := &imap.BodySectionName{}
	items := []imap.FetchItem{imap.FetchEnvelope, imap.FetchFlags, imap.FetchBody, imap.FetchBodyStructure, section.FetchItem()}

	messages := make(chan *imap.Message, 10)
	done := make(chan error, 1)
	go func() {
		done <- c.Fetch(seqSet, items, messages)
	}()

	// Process messages and download attachments
	for msg := range messages {
		log.Printf("Processing message: %s", msg.Envelope.Subject)

		r := msg.GetBody(section)
		if r == nil {
			log.Printf("No body found for message: %s", msg.Envelope.Subject)
			continue
		}

		// Create a new mail reader
		mr, err := mail.CreateReader(r)
		if err != nil {
			log.Printf("Error creating mail reader: %v", err)
			continue
		}

		// Process each message part (attachments, etc.)
		for {
			p, err := mr.NextPart()
			if err == io.EOF {
				break
			}
			if err != nil {
				log.Printf("Error getting next part: %v", err)
				break
			}

			switch h := p.Header.(type) {
			case *mail.AttachmentHeader:
				// This is an attachment
				filename, _ := h.Filename()
				log.Printf("Found attachment: %s", filename)

				// Save the attachment
				if err := eConf.saveAttachment(p.Body, filename); err != nil {
					log.Printf("Error saving attachment: %v", err)
				} else {
					log.Printf("Attachment saved: %s", filename)
				}
			}
		}
	}

	if err := <-done; err != nil {
		return fmt.Errorf("fetch error: %v", err)
	}

	return nil
}

// saveAttachment saves an email attachment to the download directory
func (ec *EmailConfig) saveAttachment(body io.Reader, filename string) error {
	// Create download directory if it doesn't exist
	if err := os.MkdirAll(ec.DownloadDir, 0755); err != nil {
		return fmt.Errorf("failed to create download directory: %v", err)
	}

	// Sanitize filename
	filename = filepath.Base(filename)

	// check if file already exists
	if _, err := os.Stat(filepath.Join(ec.DownloadDir, filename)); err == nil {
		log.Printf("File %s already exists, skipping", filename)
		return nil
	}

	filepath := filepath.Join(ec.DownloadDir, filename)

	// Create the file
	f, err := os.Create(filepath)
	if err != nil {
		return fmt.Errorf("failed to create file: %v", err)
	}
	defer f.Close()

	// Copy the attachment data to the file
	if _, err := io.Copy(f, body); err != nil {
		return fmt.Errorf("failed to save attachment: %v", err)
	}

	return nil
}

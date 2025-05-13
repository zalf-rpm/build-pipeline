package main

import (
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/emersion/go-imap/v2"
	"github.com/emersion/go-imap/v2/imapclient"
	"github.com/emersion/go-message"
	"github.com/emersion/go-message/mail"
	"github.com/emersion/go-sasl"
)

// EmailClient represents the email client that connects to the email server.
type EmailClient struct {
	IMAPServer    string
	Username      string
	Password      string
	UseOAuth      bool
	TokenProvider *TokenProvider
}

// NewEmailClient creates a new instance of EmailClient.
func NewEmailClient(config *Config) (*EmailClient, error) {
	if config == nil {
		return nil, fmt.Errorf("config cannot be nil")
	}
	if err := config.Validate(); err != nil {
		return nil, fmt.Errorf("invalid config: %v", err)
	}

	client := &EmailClient{
		IMAPServer: config.EmailServer + ":" + config.Port,
	}
	client.Username = config.Username
	if config.CredentialKey != "" {
		username, password, err := GetCredential(config.CredentialKey)
		if err != nil {
			return nil, fmt.Errorf("failed to get credentials: %v", err)
		}
		if client.Username != username {
			return nil, fmt.Errorf("username in config does not match credentials")
		}
		client.Password = password
	} else if config.Password != "" {
		client.Password = config.Password
	} else if config.UseOAuth {
		oauthConfig := &OAuthConfig{
			ClientID:     config.OAuth.ClientID,
			ClientSecret: config.OAuth.ClientSecret,
			TenantID:     config.OAuth.TenantID,
			TokenCache:   config.OAuth.TokenCache,
		}
		client.TokenProvider = NewTokenProvider(oauthConfig)
		client.UseOAuth = true
	} else {
		return nil, fmt.Errorf("no credentials provided")
	}
	return client, nil
}

type EmailConfig struct {
	From        string
	MailBox     string
	DownloadDir string
	Subject     string
	// CheckupInterval is the interval in hours to check for new emails
	CheckupInterval int
	// Verbose enables verbose logging
	Verbose bool
}

func NewEmailConfig(config *Config) *EmailConfig {
	return &EmailConfig{
		From:            config.From,
		MailBox:         config.MailBox,
		DownloadDir:     config.DownloadPath,
		Subject:         config.Subject,
		CheckupInterval: config.CheckupInterval,
		Verbose:         config.Verbose,
	}
}

// Connect authenticates the client with the email server.
func (ec *EmailClient) Connect() (*imapclient.Client, error) {
	log.Println("Connecting to server...")

	// Connect to server
	c, err := imapclient.DialTLS(ec.IMAPServer, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to server: %v", err)
	}
	log.Println("Connected")

	// Login with OAuth or Basic Authentication
	if ec.UseOAuth && ec.TokenProvider != nil {
		// Get the XOAUTH2 token
		authString, err := ec.TokenProvider.GetAccessToken()
		if err != nil {
			c.Logout()
			return nil, fmt.Errorf("failed to get OAuth token: %v", err)
		}
		if !c.Caps().Has(imap.AuthCap(sasl.OAuthBearer)) {
			c.Logout()
			return nil, fmt.Errorf("OAUTHBEARER not supported by the server")
		}

		saslClient := sasl.NewOAuthBearerClient(&sasl.OAuthBearerOptions{
			Username: ec.Username,
			Token:    authString,
		})
		if err := c.Authenticate(saslClient); err != nil {
			c.Logout()
			return nil, fmt.Errorf("authentication failed: %v", err)
		}
	} else {
		// I would have liked to use NTLM authentication, but the server, or the account does not support it

		// ask server if it supports NTLM authentication
		// if c.Caps().Has(imap.AuthCap("NTLM")) {
		// 	log.Println("Server supports NTLM authentication")
		// 	// use NTLM authentication with username and password
		// 	ntlmClient := &NTLMClient{
		// 		Username:     ec.Username,
		// 		Password:     ec.Password,
		// 		Domain:       "", // Set the domain if required
		// 		DomainNeeded: false,
		// 	}
		// 	if err := c.Authenticate(ntlmClient); err != nil {
		// 		c.Logout()
		// 		return nil, fmt.Errorf("NTLM authentication failed: %v", err)
		// 	}
		// } else
		if c.Caps().Has(imap.AuthCap("PLAIN")) {
			log.Println("Server supports PLAIN authentication")
			auth := sasl.NewPlainClient("", ec.Username, ec.Password)
			if err := c.Authenticate(auth); err != nil {
				c.Logout()
				return nil, fmt.Errorf("AUTH PLAIN failed: %v", err)
			}
		} else {
			c.Logout()
			return nil, fmt.Errorf("no supported authentication method found")
		}
	}
	log.Println("Logged in")

	return c, nil
}

// CheckForNewEmails searches for new emails and downloads their attachments
func (ec *EmailClient) CheckForNewEmails(eConf *EmailConfig, verbose bool) error {
	c, err := ec.Connect()
	if err != nil {
		return err
	}
	defer c.Logout()
	if verbose {
		mailboxes, err := c.List("", "*", nil).Collect()
		if err != nil {
			return fmt.Errorf("failed to list mailboxes: %v", err)
		}
		log.Printf("Found %v mailboxes", len(mailboxes))
		for _, mbox := range mailboxes {
			log.Printf(" - %v", mbox.Mailbox)
		}
	}
	// Select the mailbox "INBOX"
	mbox := c.Select(eConf.MailBox, &imap.SelectOptions{ReadOnly: true})
	selectMBoxData, err := mbox.Wait()
	if err != nil {
		return fmt.Errorf("failed to select mailbox: %v", err)
	}
	if selectMBoxData.NumMessages == 0 {
		log.Println("No messages in mailbox")
		return nil
	}
	if verbose {
		log.Printf("Mailbox %s selected, total messages: %d", eConf.MailBox, selectMBoxData.NumMessages)

		log.Println("Fetch Test:")
		seqSet := imap.SeqSetNum(1)
		seqSet.AddNum(selectMBoxData.NumMessages)
		fetchOptions := &imap.FetchOptions{Envelope: true}
		messages, err := c.Fetch(seqSet, fetchOptions).Collect()
		if err != nil {
			return fmt.Errorf("failed to fetch first message in INBOX: %v", err)
		}
		for _, msg := range messages {
			log.Printf("subject of message in INBOX: %v", msg.Envelope.Subject)
		}
	}
	// Search for emails within the last 24 hours
	since := time.Now().Add(-1 * time.Duration(eConf.CheckupInterval) * time.Hour)
	log.Printf("Searching for emails since %s", since.Format("02-Jan-2006 15:04:05 -0700"))

	// Search for emails with attachments from the specified sender and subject
	// within the last 24 hours
	criteria := imap.SearchCriteria{
		Since: since,
		Header: []imap.SearchCriteriaHeaderField{
			{
				Key:   "X-MS-Has-Attach",
				Value: "yes",
			},
			{
				Key:   "From",
				Value: eConf.From,
			},
			{
				Key:   "Subject",
				Value: eConf.Subject,
			},
		},
	}
	s := c.Search(&criteria, nil)
	data, err := s.Wait()
	if err != nil {
		return fmt.Errorf("SEARCH command failed: %v", err)
	}

	count := len(data.AllSeqNums()) // don't us data.count, it does not work with IMAPv1
	log.Printf("Found %d messages in the last 24 hours", eConf.CheckupInterval)

	if count == 0 {
		return nil
	}

	// Create a sequence set for the UIDs
	seqSet := imap.SeqSetNum(data.AllSeqNums()...)

	// Get the whole message body
	bodySection := &imap.FetchItemBodySection{}
	fetchOptions := &imap.FetchOptions{
		BodySection: []*imap.FetchItemBodySection{bodySection},
		Envelope:    true,
	}
	fetchCmd := c.Fetch(seqSet, fetchOptions)
	defer fetchCmd.Close()

	for msg := fetchCmd.Next(); msg != nil; msg = fetchCmd.Next() {
		var bodySectionData imapclient.FetchItemDataBodySection
		ok := false
		for {
			item := msg.Next()
			if item == nil {
				break
			}
			bodySectionData, ok = item.(imapclient.FetchItemDataBodySection)
			if ok {
				break
			}
		}

		if !ok {
			// skip if no body section found
			log.Printf("FETCH command did not return body section")
			continue
		}
		// Read the message via the go-message library
		mr, err := mail.CreateReader(bodySectionData.Literal)
		if err != nil {
			return fmt.Errorf("failed to create mail reader: %v", err)
		}

		// Process the message's parts
		for {
			p, err := mr.NextPart()
			if err == io.EOF {
				break
			} else if err != nil && !message.IsUnknownCharset(err) {
				return fmt.Errorf("failed to read message part: %v", err)
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
	if err := fetchCmd.Close(); err != nil {
		return fmt.Errorf("FETCH command failed: %v", err)
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

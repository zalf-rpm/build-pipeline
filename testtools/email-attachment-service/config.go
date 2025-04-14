package main

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// config struct

type Config struct {
	EmailServer   string `yaml:"email_server"`
	Port          string `yaml:"port"`
	SharedFolder  string `yaml:"shared_email_folder"`
	DownloadPath  string `yaml:"download_path"`
	CredentialKey string `yaml:"credential_key"`
	Username      string `yaml:"username"`
	Password      string `yaml:"password"`
	UseOAuth      bool   `yaml:"useOAuth"`

	OAuth struct {
		ClientID     string `yaml:"clientId"`
		ClientSecret string `yaml:"clientSecret"`
		TenantID     string `yaml:"tenantId"`
		TokenCache   string `yaml:"tokenCache"`
	} `yaml:"oauth"`

	// search criteria
	Subject string `yaml:"subject"`
	From    string `yaml:"from"`
}

// LoadConfig reads the configuration from a YAML file.
func LoadConfig(filePath string) (*Config, error) {

	data, err := os.ReadFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("error reading config file: %v", err)
	}

	var config Config
	if err := yaml.Unmarshal(data, &config); err != nil {
		return nil, fmt.Errorf("error unmarshalling config: %v", err)
	}

	return &config, nil
}

func (c *Config) Validate() error {
	if c.EmailServer == "" {
		return fmt.Errorf("email server is required")
	}
	if c.SharedFolder == "" {
		return fmt.Errorf("shared email folder is required")
	}
	if c.DownloadPath == "" {
		return fmt.Errorf("download path is required")
	}
	if c.Username == "" {
		return fmt.Errorf("username is required")
	}
	if !c.UseOAuth && (c.CredentialKey == "" && c.Password == "") {
		return fmt.Errorf("either credential key or password is required")
	}
	if c.UseOAuth &&
		(c.OAuth.ClientID == "" ||
			c.OAuth.ClientSecret == "" ||
			c.OAuth.TenantID == "" ||
			c.OAuth.TokenCache == "") {
		return fmt.Errorf("all OAuth fields are required")
	}

	if c.Subject == "" {
		return fmt.Errorf("subject is required")
	}
	if c.From == "" {
		return fmt.Errorf("from is required")
	}
	if c.Port == "" {
		return fmt.Errorf("port is required")
	}
	return nil
}

func WriteDummyConfig(file string) error {

	fullpath, err := filepath.Abs(file)
	if err != nil {
		return fmt.Errorf("error getting absolute path: %v", err)
	}
	// get the directory of the file
	dir := filepath.Dir(fullpath)

	// create folder
	os.MkdirAll(dir, os.ModePerm)
	// write dummy config
	config := Config{
		EmailServer:   "imap.example.com",
		Port:          "993",
		SharedFolder:  "INBOX",
		DownloadPath:  "/tmp",
		CredentialKey: "dummyKey",
		Username:      "username",
		Password:      "password",
		Subject:       "subject",
		From:          "from",
		UseOAuth:      true,
		OAuth: struct {
			ClientID     string `yaml:"clientId"`
			ClientSecret string `yaml:"clientSecret"`
			TenantID     string `yaml:"tenantId"`
			TokenCache   string `yaml:"tokenCache"`
		}{
			ClientID:     "clientId",
			ClientSecret: "clientSecret",
			TenantID:     "tenantId",
			TokenCache:   "tokenCache",
		},
	}
	data, err := yaml.Marshal(&config)
	if err != nil {
		return fmt.Errorf("error marshalling config: %v", err)
	}
	os.WriteFile(fullpath, data, os.ModePerm)
	return nil
}

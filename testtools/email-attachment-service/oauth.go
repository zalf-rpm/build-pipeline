package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/microsoft"
)

// OAuthConfig holds configuration for OAuth authentication
type OAuthConfig struct {
	ClientID     string
	ClientSecret string
	TenantID     string
	TokenCache   string
	Scopes       []string
}

// TokenProvider manages OAuth tokens
type TokenProvider struct {
	config    *OAuthConfig
	oauthConf *oauth2.Config
	token     *oauth2.Token
	cacheFile string
}

// NewTokenProvider creates a new token provider
func NewTokenProvider(config *OAuthConfig) *TokenProvider {
	cacheDir := filepath.Join(os.Getenv("APPDATA"), "EmailAttachmentService")
	err := os.MkdirAll(cacheDir, 0700)
	if err != nil {
		log.Printf("Warning: Could not create token cache directory: %v", err)
	}

	cacheFile := filepath.Join(cacheDir, "oauth_token.json")
	if config.TokenCache != "" {
		cacheFile = config.TokenCache
	}

	// Ensure default scopes if none are provided
	if len(config.Scopes) == 0 {
		config.Scopes = []string{"https://outlook.office.com/IMAP.AccessAsUser.All"}
	}

	oauthConf := &oauth2.Config{
		ClientID:     config.ClientID,
		ClientSecret: config.ClientSecret,
		Endpoint:     microsoft.AzureADEndpoint(config.TenantID),
		Scopes:       append(config.Scopes, "offline_access"),
	}

	return &TokenProvider{
		config:    config,
		oauthConf: oauthConf,
		cacheFile: cacheFile,
	}
}

// GetToken retrieves a valid OAuth token, refreshing if necessary
func (tp *TokenProvider) GetToken() (*oauth2.Token, error) {
	// Load token from cache
	if tp.token == nil {
		token, err := tp.loadTokenFromCache()
		if err == nil {
			tp.token = token
		}
	}

	// Refresh token if expired
	if tp.token != nil && tp.token.Expiry.Before(time.Now()) {
		log.Println("OAuth token expired, refreshing...")
		tokenSource := tp.oauthConf.TokenSource(context.Background(), tp.token)
		newToken, err := tokenSource.Token()
		if err != nil {
			log.Printf("Error refreshing token: %v", err)
			tp.token = nil
		} else {
			tp.token = newToken
			tp.saveTokenToCache(tp.token)
		}
	}

	// If no token, initiate OAuth flow
	if tp.token == nil {
		return nil, fmt.Errorf("no valid token available - OAuth flow not implemented for service")
	}

	return tp.token, nil
}

// loadTokenFromCache loads a cached OAuth token from disk
func (tp *TokenProvider) loadTokenFromCache() (*oauth2.Token, error) {
	data, err := os.ReadFile(tp.cacheFile)
	if err != nil {
		return nil, err
	}

	token := &oauth2.Token{}
	err = json.Unmarshal(data, token)
	if err != nil {
		return nil, err
	}

	return token, nil
}

// saveTokenToCache saves an OAuth token to disk
func (tp *TokenProvider) saveTokenToCache(token *oauth2.Token) error {
	data, err := json.Marshal(token)
	if err != nil {
		return err
	}

	return os.WriteFile(tp.cacheFile, data, 0600)
}

// GetAccess Token for XOAuth2
func (tp *TokenProvider) GetAccessToken() (string, error) {
	token, err := tp.GetToken()
	if err != nil {
		return "", err
	}
	return token.AccessToken, nil
}

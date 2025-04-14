package main

import (
	"fmt"

	"github.com/Azure/go-ntlmssp"
)

// NTLMClient implements the SASL interface for NTLM authentication
type NTLMClient struct {
	Username     string
	Password     string
	Domain       string
	DomainNeeded bool
}

// Start begins the NTLM authentication process
func (c *NTLMClient) Start() (string, []byte, error) {
	// Generate the initial NTLM negotiation message
	negotiationMessage, err := ntlmssp.NewNegotiateMessage(c.Domain, "")
	if err != nil {
		return "", nil, fmt.Errorf("failed to create NTLM negotiate message: %v", err)
	}
	return "NTLM", negotiationMessage, nil
}

// Next processes the server's challenge and generates the next NTLM message
func (c *NTLMClient) Next(challenge []byte) ([]byte, error) {
	// Generate the NTLM authenticate message using the server's challenge
	authMessage, err := ntlmssp.ProcessChallenge(challenge, c.Username, c.Password, c.DomainNeeded)
	if err != nil {
		return nil, fmt.Errorf("failed to process NTLM challenge: %v", err)
	}
	return authMessage, nil
}

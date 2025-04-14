package main

import (
	"fmt"

	"github.com/danieljoos/wincred"
	"golang.org/x/text/encoding/unicode"
	"golang.org/x/text/transform"
)

// GetCredential retrieves a credential from Windows Credential Manager
func GetCredential(key string) (string, string, error) {
	targetPrefix := "email-attachment-service"
	targetName := fmt.Sprintf("%s:%s", targetPrefix, key)

	cred, err := wincred.GetGenericCredential(targetName)
	if err != nil {
		return "", "", fmt.Errorf("failed to retrieve credential '%s': %v", key, err)
	}

	// The credential string typically has the format "username:password"
	username := cred.UserName
	if username == "" {
		return "", "", fmt.Errorf("credential '%s' not found", key)
	}
	pass := cred.CredentialBlob
	if pass == nil {
		return "", "", fmt.Errorf("credential '%s' not found", key)
	}

	// decode the blob if it is UTF-16 encoded
	decoder := unicode.UTF16(unicode.LittleEndian, unicode.IgnoreBOM).NewDecoder()
	decodedPass, _, err := transform.Bytes(decoder, pass)
	if err != nil {
		return "", "", fmt.Errorf("failed to decode password: %v", err)
	}

	if len(decodedPass) > 0 {
		pass = decodedPass
	}

	return username, string(pass), nil
}

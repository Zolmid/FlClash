package core

import (
	"errors"

	"github.com/metacubex/mihomo/component/age"
)

type AgeKeyPair struct {
	SecretKey string `json:"secret-key"`
	PublicKey string `json:"public-key"`
}

func handleGenerateAgeKeyPair() (AgeKeyPair, error) {
	secretKey, publicKey, err := age.GenX25519KeyPair()
	return AgeKeyPair{SecretKey: secretKey, PublicKey: publicKey}, err
}

func handleConvertAgeSecretKeyToPublicKey(secretKey string) (string, error) {
	publicKeys, err := age.ToPublicKeys(secretKey)
	if err != nil {
		return "", err
	}
	if len(publicKeys) == 0 {
		return "", errors.New("no public keys found")
	}
	return publicKeys[0], nil
}

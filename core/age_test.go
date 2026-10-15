package core

import (
	"testing"

	"github.com/metacubex/mihomo/component/age"
)

func TestGeneratedAgeKeysDeriveAndDecrypt(t *testing.T) {
	pair, err := handleGenerateAgeKeyPair()
	if err != nil {
		t.Fatal(err)
	}
	public, err := handleConvertAgeSecretKeyToPublicKey(pair.SecretKey)
	if err != nil || public != pair.PublicKey {
		t.Fatalf("derived public key = %q, err=%v", public, err)
	}
	encrypted, err := age.EncryptBytes([]byte("profile contents"), pair.PublicKey)
	if err != nil {
		t.Fatal(err)
	}
	plain, err := age.DecryptBytes(encrypted, pair.SecretKey)
	if err != nil || string(plain) != "profile contents" {
		t.Fatalf("generated key round trip = %q, err=%v", plain, err)
	}
	if _, err := handleConvertAgeSecretKeyToPublicKey("not-a-secret-key"); err == nil {
		t.Fatal("accepted an invalid age secret key")
	}
}

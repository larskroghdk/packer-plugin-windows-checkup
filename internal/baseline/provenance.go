package baseline

import (
	"crypto/sha256"
	"fmt"
)

// SourceCommit pins the authoritative windows-harden snapshot.
const SourceCommit = "2a3545f3a3b44c8fa84e3a22d28d999aece5daf6"

// Fingerprint returns the SHA-256 of the exact embedded baseline JSON bytes.
//
// Returns:
//   - The requested result and any validation or I/O error.
//
// Author: Lars Krogh
// Version: 0.1.0
func Fingerprint(id string) (string, error) {
	data, err := dataFS.ReadFile("data/" + id + ".json")
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%x", sha256.Sum256(data)), nil
}

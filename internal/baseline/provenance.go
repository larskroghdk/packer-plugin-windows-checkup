package baseline

import (
	"crypto/sha256"
	"fmt"
)

// SourceCommit pins the authoritative windows-harden snapshot.
const SourceCommit = "8dc70d2c81be4515ad243dfbe288d61151ab722d"

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

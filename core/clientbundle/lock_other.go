//go:build !unix && !windows

package clientbundle

func lockStore(string) (func(), error) { return func() {}, nil }

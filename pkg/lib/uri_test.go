package lib

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestRedactURI(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{
			name:  "https with credentials",
			input: "https://user:secret@broker:5672",
			want:  "https://redacted:redacted@broker:5672",
		},
		{
			name:  "http with credentials and path",
			input: "http://admin:pass@loki:3100/loki/api/v1/push",
			want:  "http://redacted:redacted@loki:3100/loki/api/v1/push",
		},
		{
			name:  "no credentials",
			input: "http://localhost:3100",
			want:  "http://localhost:3100",
		},
		{
			name:  "invalid uri",
			input: "://bad",
			want:  "redacted",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.want, RedactURI(tt.input))
		})
	}
}

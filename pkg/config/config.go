package config

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"strings"

	pkgErrors "github.com/pkg/errors"
	"gopkg.in/go-playground/validator.v9"
	"gopkg.in/yaml.v2"
)

var (
	// Validate holds config validator
	Validate = validator.New()
)

// ParseConfig parses and validates input into config object
func ParseConfig(r io.Reader, config interface{}) error {
	configBytes, err := io.ReadAll(r)
	if err != nil {
		return pkgErrors.Wrap(err, "while reading configuration")
	}
	if string(configBytes) == "null\n" {
		return nil
	}
	err = yaml.Unmarshal(configBytes, config)
	if err != nil {
		return pkgErrors.Wrap(err, "unmarshalling config yaml")
	}

	err = Validate.Struct(config)
	if err != nil {
		var e validator.ValidationErrors
		if errors.As(err, &e) {
			missingFields := []string{}
			for _, fe := range e {
				missingFields = append(missingFields, setCamelCase(fe.Namespace()))
			}
			return fmt.Errorf("missing or incorrect configuration fields --  %s --", strings.Join(missingFields, " , "))
		}
		return pkgErrors.Wrap(err, "error while validating configuration")
	}
	return nil
}

func setCamelCase(field string) string {
	items := strings.Split(field, ".")
	ret := []string{}
	for _, item := range items {
		camel := []byte(item)
		l := bytes.ToLower([]byte{camel[0]})
		camel[0] = l[0]
		ret = append(ret, string(camel))
	}
	return strings.Join(ret[1:], ".")
}

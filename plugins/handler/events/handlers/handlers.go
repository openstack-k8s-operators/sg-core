package handlers

import (
	"github.com/openstack-k8s-operators/sg-core/pkg/bus"
	"github.com/openstack-k8s-operators/sg-core/plugins/handler/events/ceilometer"
	"github.com/openstack-k8s-operators/sg-core/plugins/handler/events/collectd"
)

func ceilometerEventHandler(blob []byte, epf bus.EventPublishFunc) error {
	ceilo := ceilometer.Ceilometer{}

	err := ceilo.Parse(blob)
	if err != nil {
		return err
	}

	return ceilo.PublishEvents(epf)
}
func collectdEventHandler(blob []byte, epf bus.EventPublishFunc) error {
	clctd := collectd.Collectd{}
	err := clctd.Parse(blob)
	if err != nil {
		return err
	}

	clctd.PublishEvents(epf)
	return nil
}

// EventHandlers handle messages according to the expected data source and write parsed events to the events bus
var EventHandlers = map[string]func([]byte, bus.EventPublishFunc) error{
	"ceilometer": ceilometerEventHandler,
	"collectd":   collectdEventHandler,
}

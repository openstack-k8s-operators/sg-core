package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"os"
	"runtime/pprof"
	"sync"
	"syscall"

	"github.com/infrawatch/apputils/logging"
	"github.com/infrawatch/apputils/system"
	"github.com/infrawatch/sg-core/cmd/manager"
	"github.com/infrawatch/sg-core/pkg/config"
)

func main() {
	configPath := flag.String("config", "/etc/sg-core.conf.yaml", "configuration file path")
	cpuprofile := flag.String("cpuprofile", "", "write cpu profile to file")
	// memprofile := flag.String("memprofile", "", "write cpu profile to file")
	flag.Usage = func() {
		fmt.Printf("Usage: %s [OPTIONS]\n\nAvailable options:\n", os.Args[0])
		flag.PrintDefaults()

		fmt.Printf("\n\nDefault configurations:\n\n%s", string(configuration.Bytes()))
	}
	flag.Parse()

	logger, err := logging.NewLogger(logging.DEBUG, "console")
	if err != nil {
		fmt.Printf("failed initializing logger: %s", err)
		return
	}
	logger.Timestamp = true

	if *cpuprofile != "" {
		f, err := os.Create(*cpuprofile)
		if err != nil {
			logger.Metadata(logging.Metadata{"error": err})
			_ = logger.Error("failed to start cpu profile")
		}
		err = pprof.StartCPUProfile(f)
		if err != nil {
			logger.Metadata(logging.Metadata{"error": err})
			_ = logger.Error("failed to start cpu profile")
		}
		defer pprof.StopCPUProfile()
	}

	file, err := os.Open(*configPath)
	if err != nil {
		logger.Metadata(logging.Metadata{"error": err})
		_ = logger.Error("failed opening configuration file")
		return
	}

	err = config.ParseConfig(file, &configuration)
	if err != nil {
		logger.Metadata(logging.Metadata{"error": err})
		_ = logger.Error("failed parsing config file")
		return
	}

	logger.SetLogLevel(map[string]logging.LogLevel{
		"error": logging.ERROR,
		"warn":  logging.WARN,
		"info":  logging.INFO,
		"debug": logging.DEBUG,
	}[configuration.LogLevel])

	manager.SetLogger(logger)
	manager.SetPluginDir(configuration.PluginDir)
	manager.SetEventBusBlocking(configuration.BlockEventBus)

	for _, tConfig := range configuration.Transports {
		tName, err := manager.InitTransport(tConfig.Name, tConfig.Config)
		if err != nil {
			logger.Metadata(logging.Metadata{"transport": tConfig.Name, "error": err})
			_ = logger.Error("failed configuring transport")
			continue
		}
		err = manager.SetTransportHandlers(tName, tConfig.Handlers)
		if err != nil {
			logger.Metadata(logging.Metadata{"transport": tName, "error": err})
			_ = logger.Error("transport handlers failed to load")
			continue
		}
		logger.Metadata(logging.Metadata{"transport": tName})
		_ = logger.Info("loaded transport")
	}

	for _, aConfig := range configuration.Applications {
		err = manager.InitApplication(aConfig.Name, aConfig.Config)
		if err != nil {
			if errors.Is(err, manager.ErrAppNotReceiver) {
				logger.Metadata(logging.Metadata{"application": aConfig.Name})
				_ = logger.Warn(err.Error())
			} else {
				logger.Metadata(logging.Metadata{"application": aConfig.Name, "error": err})
				_ = logger.Error("failed configuring application")
				continue
			}
		}
		logger.Metadata(logging.Metadata{"application": aConfig.Name})
		_ = logger.Info("loaded application plugin")
	}

	// NOTE(mmagr): so if err will be just the warning from above, do we still need to end execution?
	if err != nil {
		return
	}

	ctx, cancelCtx := context.WithCancel(context.Background())
	wg := new(sync.WaitGroup)
	// run main processes

	pluginDone := make(chan bool) // notified if a plugin stops execution before main or interrupt Received
	interrupt := make(chan bool)
	manager.RunTransports(ctx, wg, pluginDone, configuration.HandlerErrors)
	manager.RunApplications(ctx, wg, pluginDone)
	system.SpawnSignalHandler(interrupt, logger, syscall.SIGINT, syscall.SIGKILL)

	for {
		select {
		case <-pluginDone:
			goto done
		case <-interrupt:
			goto done
		}
	}

done:
	cancelCtx()
	wg.Wait()
	_ = logger.Info("sg-core exited cleanly")
}

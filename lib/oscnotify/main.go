package main

import (
	"flag"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/bep/debounce"
	"github.com/hypebeast/go-osc/osc"
	"github.com/rjeczalik/notify"
	log "github.com/schollz/logger"
)

var flagRecvHost, flagRecvAddress, flagHost, flagAddress, flagPath, flagIgnore string
var flagPort int

func init() {
	flag.StringVar(&flagHost, "host", "localhost", "osc host")
	flag.StringVar(&flagIgnore, "ignore", "data", "path to ignore")
	flag.StringVar(&flagPath, "path", ".", "path to watch")
	flag.IntVar(&flagPort, "port", 10111, "port to use")
	flag.StringVar(&flagAddress, "addr", "/oscnotify", "osc address")
}

func main() {
	flag.Parse()
	// Create new watcher.
	log.SetLevel("info")
	log.Info("oscnotify started")

	c := make(chan notify.EventInfo, 1)
	pathChanged := ""
	f := func() {
		log.Debugf("sending %s to %s:%d", pathChanged, flagHost, flagPort)
		client := osc.NewClient(flagHost, flagPort)
		msg := osc.NewMessage(flagAddress)
		msg.Append(pathChanged)
		err := client.Send(msg)
		if err != nil {
			log.Error(err)
		}
	}

	debounced := debounce.New(500 * time.Millisecond)

	flagPath, _ = filepath.Abs(flagPath)
	flagIgnore, _ = filepath.Abs(flagIgnore)
	filepath.Walk(flagPath, func(path string, info os.FileInfo, err error) error {
		if info.IsDir() && !strings.Contains(path, ".git") {
			log.Debugf("watching %s", path)
			if filepath.HasPrefix(path, flagIgnore) {
				log.Tracef("ignoring '%s'", path)
				return nil
			}
			if err := notify.Watch(path, c, notify.Write); err != nil {
				log.Error(err)
			}
		}
		return nil
	})

	defer notify.Stop(c)

	// Block until an event is received.
	for {
		ei := <-c
		log.Debugf("Got event: %s", ei.Path())
		pathChanged = ei.Path()
		debounced(f)
	}

}

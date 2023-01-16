package main

import (
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"

	"github.com/hypebeast/go-osc/osc"
	log "github.com/schollz/logger"
)

var flagInput, flagOutput string
var flagHost, flagAddress string
var flagPort int
var flagStretch float64

func init() {
	flag.StringVar(&flagInput, "input", "", "input filename")
	flag.StringVar(&flagOutput, "output", "", "output filename")
	flag.StringVar(&flagHost, "host", "localhost", "osc host")
	flag.IntVar(&flagPort, "port", 10111, "port to use")
	flag.Float64Var(&flagStretch, "stretch", 0.25, "ratio to stretch")
	flag.StringVar(&flagAddress, "addr", "/soxgo", "osc address")
}

func main() {
	flag.Parse()

	log.SetLevel("error")

	var err error
	err = run()
	if err == nil {
		client := osc.NewClient(flagHost, flagPort)
		msg := osc.NewMessage(flagAddress)
		msg.Append(int32(1))
		client.Send(msg)
	}
}

func run() (err error) {
	if _, err = os.Stat(flagInput); errors.Is(err, os.ErrNotExist) {
		err = fmt.Errorf("%s does not exist", flagInput)
		log.Error(err)
		return
	}

	_, err = exec.Command("sox", flagInput, flagOutput, "tempo", "-s", fmt.Sprint(flagStretch)).Output()
	if err != nil {
		log.Error(err)
		return
	}

	return
}

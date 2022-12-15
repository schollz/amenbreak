package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"math"
	"os"
	"os/exec"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/hypebeast/go-osc/osc"
	log "github.com/schollz/logger"
)

var flagFilename string
var flagTopNumber int
var flagMinSpacing float64
var flagHost, flagAddress string
var flagPort, flagID int
var flagRM bool

type Output struct {
	Error  string        `json:"error,omitempty"`
	Timing time.Duration `json:"timing"`
	Result []float64     `json:"result,omitempty"`
}

func init() {
	flag.StringVar(&flagFilename, "filename", "", "filename")
	flag.IntVar(&flagTopNumber, "num", 16, "max number of onsets")
	flag.IntVar(&flagID, "id", 1, "id to send back")
	flag.StringVar(&flagHost, "host", "localhost", "osc host")
	flag.IntVar(&flagPort, "port", 10111, "port to use")
	flag.StringVar(&flagAddress, "addr", "/progressbar", "osc address")
	flag.BoolVar(&flagRM, "rm", false, "remove file after using")
	flag.Float64Var(&flagMinSpacing, "spacing", 0, "define the spacing (seconds)")
}

func main() {
	flag.Parse()

	log.SetLevel("error")

	var out Output
	var err error
	now := time.Now()
	out.Result, err = run()
	if err != nil {
		out.Error = fmt.Sprint(err)
	}
	out.Timing = time.Since(now)
	b, _ := json.Marshal(out)

	sendProgress(100)
	client := osc.NewClient(flagHost, flagPort)
	msg := osc.NewMessage("/aubiodone")
	msg.Append(int32(flagID))
	msg.Append(string(b))
	client.Send(msg)

	fmt.Println(string(b))

	if flagRM {
		os.Remove(flagFilename)
	}
}

func run() (top16 []float64, err error) {
	defer func() {
		newErr := recover()
		if newErr != nil {
			err = errors.New(fmt.Sprint(newErr))
		}
	}()
	top16, err = DecodeOPStarts(flagFilename)
	if err == nil {
		return
	}
	onsets, err := getOnsets()
	if err != nil {
		return
	}
	top16, err = findWindows(onsets)
	return
}

func MinMax(array []float64) (float64, float64) {
	var max float64 = array[0]
	var min float64 = array[0]
	for _, value := range array {
		if max < value {
			max = value
		}
		if min > value {
			min = value
		}
	}
	return min, max
}

func findWindows(data []float64) (top16 []float64, err error) {
	min, max := MinMax(data)
	min = 0
	win := 0.0125
	type Window struct {
		min, max float64
		data     []float64
		avg      float64
	}
	windowMap := make(map[float64]Window)
	for i := min; i < max-win; i += win / 2 {
		w := Window{i, i + win, getRange(data, i, i+win), max}
		if len(w.data) > 0 {
			w.avg = average(w.data)
		}
		windowMap[toFixed(w.avg, 2)] = w
	}

	windows := make([]Window, len(windowMap))
	j := 0
	for _, v := range windowMap {
		windows[j] = v
		j++
	}

	sort.Slice(windows, func(i, j int) bool {
		return len(windows[i].data) > len(windows[j].data)
	})

	top16 = make([]float64, flagTopNumber)
	for i, w := range windows {
		if i == flagTopNumber {
			break
		}
		top16[i] = w.avg
	}
	sort.Float64s(top16)

	// make sure to get the first one
	if top16[0] > 0.15 {
		for i := 2; i < flagTopNumber; i++ {
			top16[i] = windows[i].avg
		}
		sort.Slice(windows, func(i, j int) bool {
			return windows[i].avg < windows[j].avg
		})
		top16[0] = windows[0].avg
		sort.Float64s(top16)
	}
	return
}

func average(arr []float64) (result float64) {
	if len(arr) == 0 {
		return 0.0
	}
	sum := 0.0
	for _, v := range arr {
		sum += v
	}
	return sum / float64(len(arr))
}
func getRange(arr []float64, min, max float64) (rng []float64) {
	data := make([]float64, len(arr))
	j := 0
	for _, v := range arr {
		if v >= min && v <= max {
			data[j] = v
			j++
		}
		// assume arr is sorted
		if v > max {
			break
		}
	}
	if j > 0 {
		rng = data[:j]
	}
	return
}

func sendProgress(progress int) (err error) {
	client := osc.NewClient(flagHost, flagPort)
	msg := osc.NewMessage(flagAddress)
	msg.Append(fmt.Sprintf("[%d] determining onsets", flagID))
	msg.Append(int32(progress))
	err = client.Send(msg)
	return
}

func getOnsets() (onsets []float64, err error) {
	if flagFilename == "" {
		err = fmt.Errorf("no filename")
		return
	}
	if _, err = os.Stat(flagFilename); errors.Is(err, os.ErrNotExist) {
		err = fmt.Errorf("%s does not exist", flagFilename)
		return
	}

	duration, err := Length(flagFilename)
	if err != nil {
		return
	}

	type job struct {
		algo      string
		threshold float64
	}

	type result struct {
		result []float64
		err    error
	}

	joblist := []job{}

	for _, algo := range []string{"energy", "hfc", "specflux"} {
		for _, threshold := range []float64{5, 4.5, 4, 3.5, 3, 2.5, 2, 1.5, 1, 1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.25, 0.2, 0.1, 0.05} {
			joblist = append(joblist, job{algo, threshold})
		}
	}

	numJobs := len(joblist)
	jobs := make(chan job, numJobs)
	results := make(chan result, numJobs)

	numCPU := runtime.NumCPU()
	runtime.GOMAXPROCS(numCPU)

	for i := 0; i < numCPU; i++ {
		go func(jobs <-chan job, results chan<- result) {
			for j := range jobs {
				var r result
				var out []byte
				if flagMinSpacing == 0 {
					flagMinSpacing = duration / 128.0
				}
				out, r.err = exec.Command("aubioonset", "-i", flagFilename, "-B", "128", "-H", "128", "-t", fmt.Sprint(j.threshold), "-O", j.algo, "-M", fmt.Sprint(flagMinSpacing)).Output()
				for _, line := range strings.Split(string(out), "\n") {
					num, errNum := strconv.ParseFloat(line, 64)
					if errNum == nil {
						r.result = append(r.result, num)
					}
				}
				results <- r
			}
		}(jobs, results)
	}

	for _, j := range joblist {
		jobs <- j
	}
	close(jobs)

	data := [10000]float64{}
	j := 0
	for i := 0; i < numJobs; i++ {
		sendProgress(int(float64(i) / float64(numJobs) * 100.0))
		r := <-results
		log.Debugf("r: %+v", r)
		if r.err != nil {
			err = r.err
		} else {
			if (j == 0 && len(r.result) > 4) || (len(r.result) < 2*flagTopNumber && len(r.result) > flagTopNumber/2) {
				for _, v := range r.result {
					if j < len(data) {
						data[j] = v
						j++
					}
				}
			}
		}
	}
	onsets = data[:j]
	sort.Float64s(onsets)

	return
}

// Length returns the length of the file in seconds
func Length(fname string) (length float64, err error) {
	stdout, stderr, err := ex("sox", fname, "-n", "stat")
	if err != nil {
		return
	}
	stdout += stderr
	for _, line := range strings.Split(stdout, "\n") {
		if strings.Contains(line, "Length") {
			parts := strings.Fields(line)
			length, err = strconv.ParseFloat(parts[len(parts)-1], 64)
			return
		}
	}
	return
}

func ex(args ...string) (string, string, error) {
	log.Trace(strings.Join(args, " "))
	baseCmd := args[0]
	cmdArgs := args[1:]
	cmd := exec.Command(baseCmd, cmdArgs...)
	var outb, errb bytes.Buffer
	cmd.Stdout = &outb
	cmd.Stderr = &errb
	err := cmd.Run()
	if err != nil {
		log.Errorf("%s -> '%s'", strings.Join(args, " "), err.Error())
		log.Error(outb.String())
		log.Error(errb.String())
	}
	return outb.String(), errb.String(), err
}

func round(num float64) int {
	return int(num + math.Copysign(0.5, num))
}

func toFixed(num float64, precision int) float64 {
	output := math.Pow(10, float64(precision))
	return float64(round(num*output)) / output
}

type PatchOP struct {
	DrumVersion int    `json:"drum_version,omitempty"`
	DynaEnv     []int  `json:"dyna_env,omitempty"`
	End         []int  `json:"end,omitempty"`
	FxActive    bool   `json:"fx_active,omitempty"`
	FxParams    []int  `json:"fx_params,omitempty"`
	FxType      string `json:"fx_type,omitempty"`
	LfoActive   bool   `json:"lfo_active,omitempty"`
	LfoParams   []int  `json:"lfo_params,omitempty"`
	LfoType     string `json:"lfo_type,omitempty"`
	Name        string `json:"name,omitempty"`
	Octave      int    `json:"octave,omitempty"`
	Pitch       []int  `json:"pitch,omitempty"`
	Playmode    []int  `json:"playmode,omitempty"`
	Reverse     []int  `json:"reverse,omitempty"`
	Start       []int  `json:"start,omitempty"`
	Type        string `json:"type,omitempty"`
	Volume      []int  `json:"volume,omitempty"`
}

func DecodeOP(fname string) (patch PatchOP, err error) {
	b, err := ioutil.ReadFile(fname)
	if err != nil {
		return
	}

	index1 := bytes.Index(b, []byte("op-1"))
	if index1 < 0 {
		err = fmt.Errorf("could not find header in '%s'", fname)
		return
	}
	index2 := bytes.Index(b[index1:], []byte("}"))
	if index2 < 0 {
		err = fmt.Errorf("could not find JSON end in '%s'", fname)
		return
	}

	err = json.Unmarshal(b[index1+4:index2+index1+1], &patch)
	return
}

func DecodeOPStarts(fname string) (starts []float64, err error) {
	patch, err := DecodeOP(fname)
	if err != nil {
		return
	}
	starts = make([]float64, len(patch.Start))

	lastV := -1
	i := 0
	sort.Ints(patch.Start)
	for _, v := range patch.Start {
		if v <= lastV {
			break
		}
		starts[i] = float64(v) / 4096 / 44100
		lastV = v
		i++
	}
	starts = starts[:i]
	return
}

package main

import (
  "github.com/hypebeast/go-osc/osc"
  "fmt"
  "time"
  "flag"
  )

var sleep = flag.Duration("sleep", 0*time.Nanosecond, "how long we should sleep in nanoseconds")

func main() {
    size := 0.0

    startTime := time.Now()
    for {
      size += 1

      currentTime := time.Now()
      elapsed := currentTime.Sub(startTime) 


      client := osc.NewClient("localhost", 53000)
      msg := osc.NewMessage("/cue/title/liveText ")
      msg.Append(fmt.Sprintf("%v messages and %v elapsed", size, elapsed))

      client.Send(msg)

      fmt.Println("sending", msg)
    }
}

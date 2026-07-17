// zed-cp companion listener.
// Receives problems from the Competitive Companion browser extension and writes
// <root>/<group>/<name>.cpp + <root>/<group>/tests/<name>/N.in/N.out, then opens
// them in Zed. Port 27121 is in Competitive Companion's default broadcast list.
//
// Config via env:
//   ZED_CP_ROOT         problem root dir      (default ~/cp)
//   ZED_CP_TEMPLATE_DIR dir with template.cpp (default ~/.config/zed-cp/templates)
//   ZED_CP_TEMPLATE     "cp" (single) or "cpt" (multitest)  (default cp)
//   ZED_CLI             explicit path to the Zed CLI (else auto-detected)
//
// Build: go build -o cp-listener companion-listener.go
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
)

var nonAlnum = regexp.MustCompile(`[^a-z0-9]+`)

func port() string { return env("ZED_CP_PORT", "27121") }

func home() string {
	h, _ := os.UserHomeDir()
	return h
}

// configFile parses ~/.config/zed-cp/config (simple KEY="value" / KEY=value
// lines, # comments) once. It is the single source of truth; env still wins.
var cfgCache map[string]string

func configFile() map[string]string {
	if cfgCache != nil {
		return cfgCache
	}
	cfgCache = map[string]string{}
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		base = filepath.Join(home(), ".config")
	}
	f, err := os.ReadFile(filepath.Join(base, "zed-cp", "config"))
	if err != nil {
		return cfgCache
	}
	for _, line := range strings.Split(string(f), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		v = strings.TrimSpace(v)
		v = strings.Trim(v, `"'`)
		cfgCache[strings.TrimSpace(k)] = v
	}
	return cfgCache
}

// env resolves a setting: process env first, then the config file, then default.
func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	if v, ok := configFile()[k]; ok && v != "" {
		return v
	}
	return def
}

func root() string { return env("ZED_CP_ROOT", filepath.Join(home(), "cp")) }

func templateDir() string {
	return env("ZED_CP_TEMPLATE_DIR", filepath.Join(home(), ".config", "zed-cp", "templates"))
}

func templatePath() string {
	name := "template.cpp"
	if os.Getenv("ZED_CP_TEMPLATE") == "cpt" {
		name = "template-multi.cpp"
	}
	return filepath.Join(templateDir(), name)
}

// zedCLI locates the Zed command line across platforms; "" if not found.
func zedCLI() string {
	if p := os.Getenv("ZED_CLI"); p != "" {
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	for _, name := range []string{"zed", "zeditor"} {
		if p, err := exec.LookPath(name); err == nil {
			return p
		}
	}
	if runtime.GOOS == "darwin" {
		mac := "/Applications/Zed.app/Contents/MacOS/cli"
		if _, err := os.Stat(mac); err == nil {
			return mac
		}
	}
	return ""
}

func openInZed(files []string) {
	cli := zedCLI()
	if cli == "" {
		return
	}
	_ = exec.Command(cli, files...).Start()
	_ = exec.Command(cli, files[0]).Start() // focus source
}

type payload struct {
	Name  string `json:"name"`
	Group string `json:"group"`
	Tests []struct {
		Input  string `json:"input"`
		Output string `json:"output"`
	} `json:"tests"`
}

func slug(s string) string {
	s = strings.ToLower(s)
	s = nonAlnum.ReplaceAllString(s, "-")
	s = strings.Trim(s, "-")
	if len(s) > 60 {
		s = s[:60]
	}
	if s == "" {
		return "problem"
	}
	return s
}

func handle(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		fmt.Fprint(w, "zed-cp listener up")
		return
	}
	body, _ := io.ReadAll(r.Body)
	var p payload
	if err := json.Unmarshal(body, &p); err != nil {
		http.Error(w, "bad", http.StatusBadRequest)
		fmt.Println("bad payload:", err)
		return
	}
	group, name := slug(p.Group), slug(p.Name)
	if group == "problem" {
		group = "misc"
	}
	dir := filepath.Join(root(), group)
	tdir := filepath.Join(dir, "tests", name)
	if err := os.MkdirAll(tdir, 0o755); err != nil {
		http.Error(w, "mkdir", http.StatusInternalServerError)
		return
	}
	for i, t := range p.Tests {
		n := fmt.Sprintf("%d", i+1)
		_ = os.WriteFile(filepath.Join(tdir, n+".in"), []byte(t.Input), 0o644)
		_ = os.WriteFile(filepath.Join(tdir, n+".out"), []byte(t.Output), 0o644)
	}
	sol := filepath.Join(dir, name+".cpp")
	if _, err := os.Stat(sol); err != nil {
		tpl, e := os.ReadFile(templatePath())
		if e != nil {
			tpl = []byte("#include <bits/stdc++.h>\nusing namespace std;\nint main(){\n    \n}\n")
		}
		_ = os.WriteFile(sol, tpl, 0o644)
	}
	fmt.Printf("[%d tests] %s\n", len(p.Tests), sol)
	openInZed([]string{sol, filepath.Join(tdir, "1.in"), filepath.Join(tdir, "1.out")})
	fmt.Fprint(w, "ok")
}

func main() {
	http.HandleFunc("/", handle)
	fmt.Printf("zed-cp listening on :%s -> %s\n", port(), root())
	if err := http.ListenAndServe(":"+port(), nil); err != nil {
		fmt.Println(err) // port busy = another instance; exit cleanly
		os.Exit(0)
	}
}

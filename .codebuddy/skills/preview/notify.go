///usr/bin/env go run "$0" "$@" ; exit $?

//go:build ignore

package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"
)

// envdEnvsURL 是沙箱内部 envd 暴露的环境变量接口
// 返回扁平的 key-value JSON，如 {"X_IDE_SPACE_KEY":"...","X_IDE_PREVIEW_DOMAIN":"..."}
const envdEnvsURL = "http://127.0.0.1:49983/envs"

// fetchEnvFromEnvd 调用 envd /envs 接口，获取所有环境变量
func fetchEnvFromEnvd() (map[string]string, error) {
	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get(envdEnvsURL)
	if err != nil {
		return nil, fmt.Errorf("request envd: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("envd returned status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read envd body: %w", err)
	}

	// envd 返回的是扁平 key-value JSON，值可能不是 string，统一转字符串
	raw := map[string]any{}
	if err := json.Unmarshal(body, &raw); err != nil {
		return nil, fmt.Errorf("parse envd body: %w", err)
	}

	envs := make(map[string]string, len(raw))
	for k, v := range raw {
		if v == nil {
			continue
		}
		switch val := v.(type) {
		case string:
			envs[k] = val
		default:
			b, _ := json.Marshal(val)
			envs[k] = string(b)
		}
	}
	return envs, nil
}

// resolveEnv 优先读 os.Getenv，缺失时从 envd 兜底
func resolveEnv(keys ...string) map[string]string {
	result := make(map[string]string, len(keys))
	missing := false
	for _, k := range keys {
		if v := os.Getenv(k); v != "" {
			result[k] = v
		} else {
			missing = true
		}
	}
	if !missing {
		return result
	}

	envs, err := fetchEnvFromEnvd()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Warning: fetch envs from envd failed: %v\n", err)
		return result
	}
	for _, k := range keys {
		if _, ok := result[k]; ok {
			continue
		}
		if v, ok := envs[k]; ok && v != "" {
			result[k] = v
		}
	}
	return result
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "Usage: notify <port>")
		os.Exit(1)
	}

	port := os.Args[1]

	// 验证端口是否在监听
	out, err := exec.Command("lsof", "-i:"+port, "-sTCP:LISTEN").CombinedOutput()
	if err != nil || len(strings.TrimSpace(string(out))) == 0 {
		fmt.Fprintf(os.Stderr, "Error: no service listening on port %s, please make sure the server is running\n", port)
		os.Exit(1)
	}

	// X_IDE_SPACE_KEY 与 AGENT_RUNTIME_SANDBOX_ID 同等作用（均为沙箱 ID）：
	//   - AGS 沙箱：通过 UpdateSandbox 注入 X_IDE_SPACE_KEY，webview 域名带 e2b. 子域；
	//   - 其他场景（如 CS）：注入 AGENT_RUNTIME_SANDBOX_ID 作为兜底，webview 域名不带 e2b. 子域。
	// 两者只要拿到一个即可拼出 webview URL，但 host 前缀的拼法不同。
	envs := resolveEnv("X_IDE_SPACE_KEY", "AGENT_RUNTIME_SANDBOX_ID", "X_IDE_PREVIEW_DOMAIN")
	spaceKey := envs["X_IDE_SPACE_KEY"]
	useE2BPrefix := true
	if spaceKey == "" {
		spaceKey = envs["AGENT_RUNTIME_SANDBOX_ID"]
		useE2BPrefix = false
	}
	previewDomain := envs["X_IDE_PREVIEW_DOMAIN"]

	if spaceKey == "" || previewDomain == "" {
		fmt.Fprintf(os.Stderr,
			"Error: missing required envs (X_IDE_SPACE_KEY/AGENT_RUNTIME_SANDBOX_ID=%q, X_IDE_PREVIEW_DOMAIN=%q), and envd fallback did not provide them\n",
			spaceKey, previewDomain)
		os.Exit(1)
	}

	host := "webview." + previewDomain
	if useE2BPrefix {
		host = "webview.e2b." + previewDomain
	}
	url := fmt.Sprintf("https://%s/?x-cs-sandbox-id=%s&x-cs-sandbox-port=%s", host, spaceKey, port)

	payload, _ := json.Marshal(map[string]string{
		"port": port,
		"url":  url,
	})
	fmt.Printf("[Preview] %s\n", payload)
}

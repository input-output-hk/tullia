package action

_lib: github: pull_request: {
	#input:  *null | string
	#repo:   string
	#target: string
}

if _lib.github.pull_request.#input != null {
	let cfg = _lib.github.pull_request

	inputs: "\(cfg.#input)": "github-event": cfg & {
		action: "opened" | "reopened" | "synchronize"
		pull_request: {
			base: ref: cfg.#target
			head: {
				repo: full_name: cfg.#repo
				sha: string
			}
			"_links": statuses: href: string
		}
		repository: full_name: cfg.#repo
	}

	output: success: {
		let event = _inputs["\(cfg.#input)"].value."github-event"
		ok:       true
		head_sha: event.pull_request.head.sha
	}
}

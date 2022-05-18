package action

_lib: github: pull_request?: {
	#input:   string | *"GitHub Pull Request"
	#repo:    string
	#target?: string
	#target_default: bool | *false
}

let cfg = _lib.github.pull_request

if cfg != _|_ {
	inputs: "\(cfg.#input)": match: "github-event": cfg & {
		action: "opened" | "reopened" | "synchronize"

		repository: full_name: cfg.#repo

		pull_request: {
			if cfg.#target != _|_ {
				base: ref: cfg.#target
			}

			head: {
				repo: clone_url: string
				sha: string
			}

			"_links": statuses: href: string
		}

		if cfg.#target_default {
			pull_request: base: ref: repository.default_branch
			repository: default_branch: string
		}
	}

	output: success: {
		let event = inputs[cfg.#input].value."github-event"
		ok: true
		head: sha: event.pull_request.head.sha
	}
}

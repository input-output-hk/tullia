_lib: github: {
	#input: string | *"GitHub event"
	#repo:  string | *null

	pull_request?: {
		#repo: =~"^[^/]+/[^/]+$"
		if github.#repo != null {
			#repo: github.#repo
		}
		#target?:        string
		#target_default: bool | *true
	}

	push?: {
		#repo: =~"^[^/]+/[^/]+$"
		if github.#repo != null {
			#repo: github.#repo
		}
		#branch?:        string
		#tag?:           string
		#default_branch: bool | *true
	}
}

inputs: "\(_lib.github.#input)": match: "github-event": or([
							{// (indent is messed up by cue fmt)
		let cfg = _lib.github.pull_request

		if cfg != _|_ {
			cfg & {
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
				}

				if cfg.#target_default {
					pull_request: base: ref: repository.default_branch
					repository: default_branch: string
				}
			}
		}
	},
	{
		let cfg = _lib.github.push

		if cfg != _|_ {
			cfg & {
				pusher: {}
				deleted: false
				repository: full_name: cfg.#repo
				head_commit: id:       string

				ref: string
				if cfg.#branch != _|_ || cfg.#tag != _|_ {
					ref: or([
						if cfg.#branch != _|_ {
							=~"^refs/heads/\(cfg.#branch)$"
						},
						if cfg.#tag != _|_ {
							=~"^refs/tags/\(cfg.#tag)$"
						},
					])
				}

				if cfg.#default_branch {
					_lib: github: push: #branch: repository.default_branch
					repository: default_branch: string
				}
			}
		}
	},
])

output: {
	success: ok: true

	let event = inputs[_lib.github.#input].value."github-event"
	[string]: revision:
		event.pull_request.head.sha | // PR
		event.head_commit.id // push
}

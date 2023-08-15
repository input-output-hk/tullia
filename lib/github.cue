import "strings"

inputs: _
let final_inputs = inputs

#lib: io: {
	let #repo_full_name = =~"^[^/]+/[^/]+$"

	github_pr: {
		#input: {
			result: string | *"GitHub PR to \(#repo)\(_target)\(_target_default)"

			_target: *" against branch \(#target)" | ""

			_target_default: string
			if #target_default {
				_target_default: " against default branch"
			}
			if !#target_default {
				_target_default: ""
			}
		}.result

		#repo:           #repo_full_name
		#target?:        string
		#target_default: bool | *false

		inputs: "\(#input)": match: {
			github_event: "pull_request"
			github_body: {
				action: "opened" | "reopened" | "synchronize"

				repository: {
					full_name:      #repo
					default_branch: string
				}

				pull_request: {
					head: sha: string
					base: ref: string & {
						let terms = [
							if #target_default {
								repository.default_branch
							},
							if #target != _|_ {
								=~"^\(#target)$"
							},
						]
						if len(terms) != 0 {or(terms)}
					}
				}
			}
		}

		output: {
			success: ok: true
			failure: ok: false
			if _revision != _|_ {
				[string]: revision: _revision
			}
		}

		let body = final_inputs[#input].match.github_body
		_repo:           body.repository.full_name
		_target:         body.pull_request.base.ref
		_default_branch: body.repository.default_branch
		_revision:       body.pull_request.head.sha
	}

	github_push: {
		#input: {
			result: string | *"GitHub Push to \(#repo)\(_branch)\(_default_branch)\(_tag)"

			_branch: *" on branch \(#branch)" | ""

			_default_branch: string
			if #default_branch {
				_default_branch: " on default branch"
			}
			if !#default_branch {
				_default_branch: ""
			}

			_tag: *" on tag \(#tag)" | ""
		}.result

		#repo:           #repo_full_name
		#branch?:        string
		#tag?:           string
		#default_branch: bool | *false

		inputs: "\(#input)": match: {
			github_event: "push"
			github_body: {
				deleted: false
				head_commit: id: string

				repository: {
					full_name:      #repo
					default_branch: string
				}

				ref: string & {
					let terms = [
						if #default_branch {
							"refs/heads/\(repository.default_branch)"
						},
						if #branch != _|_ {
							=~"^refs/heads/(\(#branch))$"
						},
						if #tag != _|_ {
							=~"^refs/tags/(\(#tag))$"
						},
					]
					if len(terms) != 0 {or(terms)}
				}
			}
		}

		output: {
			success: ok: true
			failure: ok: false
			[string]: {
				if _revision != _|_ {
					revision: _revision
				}
				if _tag != _|_ {
					tag: _tag
				}
			}
		}

		let body = final_inputs[#input].match.github_body
		_repo:           body.repository.full_name
		_default_branch: body.repository.default_branch
		_revision:       body.head_commit.id
		_branch: {
			let prefix = "refs/heads/"
			let hasPrefix = strings.HasPrefix(body.ref, prefix)
			if hasPrefix {
				strings.TrimPrefix(body.ref, prefix)
			}
			if !hasPrefix {
				_|_
			}
		}
		_tag: {
			let prefix = "refs/tags/"
			let hasPrefix = strings.HasPrefix(body.ref, prefix)
			if hasPrefix {
				strings.TrimPrefix(body.ref, prefix)
			}
			if !hasPrefix {
				_|_
			}
		}
	}

	github_pr_comment: {
		#input:   string | *"GitHub PR comment to \(#repo)"

		#repo:    =~"^[^/]+/[^/]+$"
		#comment: string

		inputs: {

			"\(#input)": match: {
				github_event: "issue_comment"
				github_body: {
					action: "created"

					repository: full_name: #repo

					issue: pull_request: {}

					comment: body: =~#comment
				}
			}
		}

		let _body = inputs["\(#input)"].value.github_body
		_repo:    _body.repository.full_name
		_comment: _body.comment.body
		_number:  _body.issue.number
	}
}

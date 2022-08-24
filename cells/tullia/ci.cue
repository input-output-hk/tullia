 let github = {// (indent is messed up by cue fmt)
	#input: "GitHub event"
	#repo:  "input-output-hk/tullia"
}

#lib.merge
#ios: [
	#lib.io.github_pr & github,
	#lib.io.github_push & github,
]

#lib: io: slack_message: {
	#input: string | *"Slack Message"
	#channels?: [...string]
	#user?:    string
	#message?: string

	inputs: "\(#input)": match: {}
}

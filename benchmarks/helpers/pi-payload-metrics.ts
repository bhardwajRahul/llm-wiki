import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { appendFileSync } from "node:fs";

export default function payloadMetrics(pi: ExtensionAPI) {
	pi.on("before_provider_request", (event) => {
		const outputPath = process.env.LLM_WIKI_PI_METRICS_PATH;
		if (!outputPath) return;

		const rendered = JSON.stringify(event.payload);
		appendFileSync(
			outputPath,
			`${JSON.stringify({
				payload_bytes: Buffer.byteLength(rendered, "utf8"),
				payload_chars: rendered.length,
				estimated_tokens: Math.ceil(rendered.length / 3),
			})}\n`,
			"utf8",
		);
	});
}

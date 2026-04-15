import { describe, expect, test } from "bun:test";
import { resolve } from "node:path";
import { datasets } from "../index.ts";

const publicDir = resolve(import.meta.dir, "../public");

describe("catalog integrity", () => {
	for (const dataset of datasets) {
		describe(dataset.id, () => {
			for (const version of dataset.versions) {
				describe(`version ${version.id}`, () => {
					if (version.sizes) {
						for (const size of version.sizes) {
							test(`size "${size.label}" file exists: ${size.path}`, async () => {
								const file = Bun.file(resolve(publicDir, size.path));
								expect(await file.exists()).toBe(true);
							});
						}
					}

					if (version.sampleQueries) {
						for (const query of version.sampleQueries) {
							test(`query "${query.label}" file exists: ${query.path}`, async () => {
								const file = Bun.file(resolve(publicDir, query.path));
								expect(await file.exists()).toBe(true);
							});
						}
					}
				});
			}
		});
	}
});

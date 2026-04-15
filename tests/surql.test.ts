import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { resolve } from "node:path";
import { createNodeEngines } from "@surrealdb/node";
import { Glob } from "bun";
import { createRemoteEngines, Surreal } from "surrealdb";

const publicDir = resolve(import.meta.dir, "../public");

async function createDb(): Promise<Surreal> {
	const db = new Surreal({
		engines: {
			...createRemoteEngines(),
			...createNodeEngines(),
		},
	});
	await db.connect("mem://");
	await db.use({ namespace: "test", database: "test" });
	return db;
}

async function readSurql(relativePath: string): Promise<string> {
	const file = Bun.file(resolve(publicDir, relativePath));
	return file.text();
}

// ---------------------------------------------------------------------------
// Dataset import tests — verify each v3 dataset .surql file can be executed
// against an in-memory SurrealDB without errors.
// The embedded engine is SurrealDB v3, so only v3-syntax files are tested.
// ---------------------------------------------------------------------------

describe("dataset imports (v3)", () => {
	const datasetFiles = ["datasets/surreal-deal-store/mini-v3.surql"];

	for (const file of datasetFiles) {
		test(
			`imports without errors: ${file}`,
			async () => {
				const db = await createDb();
				try {
					const surql = await readSurql(file);
					const results = await db.query(surql);
					expect(results).toBeDefined();
				} finally {
					await db.close();
				}
			},
			{ timeout: 30_000 },
		);
	}
});

// ---------------------------------------------------------------------------
// Sample query tests — load the mini-v3 dataset, then run each query file
// against it to verify the queries execute without throwing.
// ---------------------------------------------------------------------------

describe("sample queries (surreal-deal-store)", () => {
	let db: Surreal;

	beforeAll(async () => {
		db = await createDb();
		const surql = await readSurql("datasets/surreal-deal-store/mini-v3.surql");
		await db.query(surql);
	}, 30_000);

	afterAll(async () => {
		await db.close();
	});

	const queryFiles = Array.from(
		{ length: 9 },
		(_, i) => `datasets/surreal-deal-store/queries/query-${i + 1}.surql`,
	);

	for (const file of queryFiles) {
		test(`executes without errors: ${file}`, async () => {
			const surql = await readSurql(file);
			const results = await db.query(surql);
			expect(results).toBeDefined();
		});
	}
});

// ---------------------------------------------------------------------------
// Self-contained query files (surreal-start) — these create their own data,
// so each runs in its own fresh database.
// v2-specific files are skipped since the embedded engine runs SurrealDB v3.
// ---------------------------------------------------------------------------

describe("surreal-start queries", () => {
	const queryFiles = [
		"datasets/surreal-start/queries/surrealql-basics.surql",
		"datasets/surreal-start/queries/vector-queries.surql",
	];

	for (const file of queryFiles) {
		test(
			`executes without errors: ${file}`,
			async () => {
				const db = await createDb();
				try {
					const surql = await readSurql(file);
					const results = await db.query(surql);
					expect(results).toBeDefined();
				} finally {
					await db.close();
				}
			},
			{ timeout: 30_000 },
		);
	}

	// graph-queries-v2 uses type::thing() which was renamed in v3 — skipped.
	// graph-queries-v3 uses DELETE on non-existent tables as an interactive
	// cleanup step, which throws in a fresh database — skipped.
	test.skip("skipped (v2 syntax): datasets/surreal-start/queries/graph-queries-v2.surql", () => {});
	test.skip("skipped (interactive cleanup): datasets/surreal-start/queries/graph-queries-v3.surql", () => {});
});

// ---------------------------------------------------------------------------
// Syntax check — verify every .surql file under public/ can be read and is
// non-empty.
// ---------------------------------------------------------------------------

describe("all surql files are non-empty", () => {
	const glob = new Glob("**/*.surql");
	const allFiles = Array.from(glob.scanSync({ cwd: publicDir }));

	for (const file of allFiles) {
		test(`non-empty: ${file}`, async () => {
			const content = await Bun.file(resolve(publicDir, file)).text();
			expect(content.trim().length).toBeGreaterThan(0);
		});
	}
});

import { existsSync, mkdirSync, writeFileSync } from "node:fs";

interface Dataset {
	id: string;
	label: string;
	description: string;
	author: string;
	hidden: boolean;
	showForDeploy: boolean;
	versions: Version[];
}

interface Version {
	id: string;
	hidden: boolean;
	minimumVersion: string;
	sizes?: Size[];
	sampleQueries?: Query[];
}

interface Query {
	id: string;
	label: string;
	path: string;
}

interface Size {
	id: string;
	hidden: boolean;
	label: string;
	path: string;
}

const datasets: Dataset[] = [
	{
		id: "surreal-deal-store",
		label: "Surreal Deal Store",
		description:
			"A sample dataset based on the real SurrealDB store made up of 12 tables. Uses graph relations and record links.",
		author: "SurrealDB Team",
		hidden: false,
		showForDeploy: true,
		versions: [
			{
				id: "v2",
				hidden: false,
				minimumVersion: "2.0",
				sizes: [
					{
						id: "mini",
						hidden: false,
						label: "Mini",
						path: "datasets/surreal-deal-store/mini-v2.surql",
					},
					{
						id: "standard",
						hidden: false,
						label: "Standard",
						path: "datasets/surreal-deal-store/standard-v2.surql",
					},
				],
				sampleQueries: [
					{
						id: "record-links",
						label: "Record links",
						path: "datasets/surreal-deal-store/queries/query-1.surql",
					},
					{
						id: "graph-relations",
						label: "Graph relations",
						path: "datasets/surreal-deal-store/queries/query-2.surql",
					},
					{
						id: "conditional-filtering",
						label: "Conditional filtering",
						path: "datasets/surreal-deal-store/queries/query-3.surql",
					},
					{
						id: "relation-filtering",
						label: "Relation filtering",
						path: "datasets/surreal-deal-store/queries/query-4.surql",
					},
					{
						id: "counting",
						label: "Counting",
						path: "datasets/surreal-deal-store/queries/query-5.surql",
					},
					{
						id: "unique-items",
						label: "Unique items",
						path: "datasets/surreal-deal-store/queries/query-6.surql",
					},
					{
						id: "aggregation",
						label: "Aggregation",
						path: "datasets/surreal-deal-store/queries/query-7.surql",
					},
					{
						id: "functions",
						label: "Functions",
						path: "datasets/surreal-deal-store/queries/query-8.surql",
					},
					{
						id: "function-filtering",
						label: "Function filtering",
						path: "datasets/surreal-deal-store/queries/query-9.surql",
					},
				],
			},
			{
				id: "v3",
				hidden: true,
				minimumVersion: "3.0",
				sizes: [
					{
						id: "mini",
						hidden: false,
						label: "Mini",
						path: "datasets/surreal-deal-store/mini-v3.surql",
					},
					{
						id: "standard",
						hidden: false,
						label: "Standard",
						path: "datasets/surreal-deal-store/standard-v3.surql",
					},
				],
				sampleQueries: [
					{
						id: "record-links",
						label: "Record links",
						path: "datasets/surreal-deal-store/queries/query-1.surql",
					},
					{
						id: "graph-relations",
						label: "Graph relations",
						path: "datasets/surreal-deal-store/queries/query-2.surql",
					},
					{
						id: "conditional-filtering",
						label: "Conditional filtering",
						path: "datasets/surreal-deal-store/queries/query-3.surql",
					},
					{
						id: "relation-filtering",
						label: "Relation filtering",
						path: "datasets/surreal-deal-store/queries/query-4.surql",
					},
					{
						id: "counting",
						label: "Counting",
						path: "datasets/surreal-deal-store/queries/query-5.surql",
					},
					{
						id: "unique-items",
						label: "Unique items",
						path: "datasets/surreal-deal-store/queries/query-6.surql",
					},
					{
						id: "aggregation",
						label: "Aggregation",
						path: "datasets/surreal-deal-store/queries/query-7.surql",
					},
					{
						id: "functions",
						label: "Functions",
						path: "datasets/surreal-deal-store/queries/query-8.surql",
					},
					{
						id: "function-filtering",
						label: "Function filtering",
						path: "datasets/surreal-deal-store/queries/query-9.surql",
					},
				],
			},
		],
	},
	{
		id: "surreal-start",
		label: "Surreal Start",
		description:
			"A simple introductory dataset to help you get started with using SurrealDB.",
		author: "SurrealDB Team",
		hidden: false,
		showForDeploy: true,
		versions: [
			{
				id: "v2",
				hidden: false,
				minimumVersion: "2.0",
				sampleQueries: [
					{
						id: "surrealql-basics",
						label: "SurrealQL Basics",
						path: "datasets/surreal-start/queries/surrealql-basics.surql",
					},
					{
						id: "graph-queries",
						label: "Graph Queries",
						path: "datasets/surreal-start/queries/graph-queries-v2.surql",
					},
					{
						id: "vector-queries",
						label: "Vector Queries",
						path: "datasets/surreal-start/queries/vector-queries.surql",
					},
					{
						id: "authentication",
						label: "Authentication",
						path: "datasets/surreal-start/queries/auth-queries-v2.surql",
					},
				],
			},
			{
				id: "v3",
				hidden: false,
				minimumVersion: "3.0",
				sampleQueries: [
					{
						id: "surrealql-basics",
						label: "SurrealQL Basics",
						path: "datasets/surreal-start/queries/surrealql-basics.surql",
					},
					{
						id: "graph-queries",
						label: "Graph Queries",
						path: "datasets/surreal-start/queries/graph-queries-v3.surql",
					},
					{
						id: "vector-queries",
						label: "Vector Queries",
						path: "datasets/surreal-start/queries/vector-queries.surql",
					},
					{
						id: "authentication",
						label: "Authentication",
						path: "datasets/surreal-start/queries/auth-queries-v3.surql",
					},
				],
			},
		],
	},
	{
		id: "surreal-search",
		label: "Surreal Search",
		description:
			"A hybrid documentation search dataset showcasing full-text BM25, vector (HNSW) semantic search, hybrid ranking, incremental indexing, and exposing search through a defined function and API.",
		author: "SurrealDB Team",
		hidden: false,
		showForDeploy: true,
		versions: [
			{
				id: "v3",
				hidden: false,
				minimumVersion: "3.0",
				sizes: [
					{
						id: "standard",
						hidden: false,
						label: "Standard",
						path: "datasets/surreal-search/queries/1-schema-and-sample-data.surql"
					}	
				],
				sampleQueries: [
					{
						id: "schema-and-sample-data",
						label: "Schema & Sample Data",
						path: "datasets/surreal-search/queries/1-schema-and-sample-data.surql",
					},
					{
						id: "full-text-and-bm25-search",
						label: "Full-Text & BM25 Search",
						path: "datasets/surreal-search/queries/2-full-text-and-bm25-search.surql",
					},
					{
						id: "vector-semantic-search",
						label: "Vector Semantic Search",
						path: "datasets/surreal-search/queries/3-vector-semantic-search.surql",
					},
					{
						id: "hybrid-search",
						label: "Hybrid Search",
						path: "datasets/surreal-search/queries/4-hybrid-search.surql",
					},
					{
						id: "incremental-indexing",
						label: "Incremental Indexing",
						path: "datasets/surreal-search/queries/5-incremental-indexing.surql",
					},
					{
						id: "define-function-and-api",
						label: "Define Function & API",
						path: "datasets/surreal-search/queries/6-define-function-and-api.surql",
					},
				],
			},
		],
	},
];

console.log("Building datasets...");

if (!existsSync("out")) {
	console.log("Creating output directory...");
	mkdirSync("out");
}

console.log("Writing datasets.json to output directory...");
writeFileSync("out/datasets.json", JSON.stringify(datasets, null, 4));

console.log("Done!");

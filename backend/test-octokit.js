const { Octokit } = require("@octokit/rest");
async function run() {
  const octokit = new Octokit();
  const res = await octokit.rest.pulls.get({
    owner: "Sellio-Squad",
    repo: "sellio_metrics",
    pull_number: 57
  });
  console.log("changed_files:", res.data.changed_files);
  console.log("additions:", res.data.additions);
  console.log("deletions:", res.data.deletions);
}
run();

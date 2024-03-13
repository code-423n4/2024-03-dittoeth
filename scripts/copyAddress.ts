const fs = require("fs").promises;
const path = require("path");
const getDirName = path.dirname;

const fileExists = async (path: string) =>
  !!(await fs.stat(path).catch(() => false));

async function writeFile(path: string, contents: string) {
  await fs.mkdir(getDirName(path), { recursive: true });
  await fs.writeFile(path, contents);
}

const invertKeyValues = (obj: { [key: string]: string }) =>
  Object.keys(obj).reduce((acc: { [key: string]: string }, key) => {
    acc[obj[key]] = key;
    return acc;
  }, {});

const addressPath = "frontend/abi/addresses.ts";
const preString = `// THIS IS A GENERATED FILE FROM ./scripts/copyAddress.ts
export default `;

// copy deployed addresses from anvil to addressPath for front end
async function copyAddress() {
  const DEPLOY_DIR = ".deploy-snapshots";
  let dirPath = path.join(process.cwd(), DEPLOY_DIR);
  let ext = ".snap";
  let snapshots;

  let exists = await fileExists(addressPath);
  let addresses: { [key: string]: { [key: string]: string } };
  if (exists) {
    let file = await fs.readFile(addressPath);

    try {
      let temp = file.toString().substring(preString.length - 1);
      addresses = JSON.parse(temp);
    } catch (e) {
      throw e;
    }
  } else {
    addresses = {
      1: {},
      31337: {},
      5: {},
    };
  }

  try {
    snapshots = await fs.readdir(dirPath);
  } catch (e) {
    console.log(`nothing in ${DEPLOY_DIR}/ to copy`);
    return;
  }
  if (!snapshots) {
    return;
  }

  for (let snapshot of snapshots) {
    let addressPath = path.join(dirPath, snapshot);
    if (!addressPath.endsWith(ext)) {
      continue;
    }

    let parsed;
    try {
      let file = await fs.readFile(addressPath);
      parsed = file.toString();
    } catch (e) {
      throw e;
    }

    let baseName = path.basename(snapshot).slice(0, -1 * +ext.length);
    let contract = baseName.split("-")[0];
    let chainId = Number(baseName.split("-")[1]);

    if (chainId == 1 || chainId == 31337 || chainId == 5) {
      addresses[chainId][contract] = parsed;
    }
  }

  let deployPath = path.join(process.cwd(), addressPath);
  try {
    await fs.rm(dirPath, { recursive: true, force: true });

    let inverted = invertKeyValues(addresses["31337"]);
    Object.entries(inverted).forEach(([key, value]) => {
      if (value == "deth" || value == "dusd") {
        inverted[key] = "asset";
      }
      if (value == "reth") {
        inverted[key] = "rocketTokenReth";
      }
      inverted[key] += "ABI";
    });
    addresses.inverted = inverted;

    let newString = `${preString}${JSON.stringify(addresses, null, 2)}`;
    await writeFile(deployPath, newString);
  } catch {}

  console.log(`Contract Addresses Copied to ${deployPath}`);
}

// const GENERATED_WAGMI_PATH = "frontend/abi/generated.ts";
// const ABI_PATH = "frontend/abi/abi.ts";

// async function copyABI() {
//   const content = await fs.readFile(GENERATED_WAGMI_PATH, "utf-8");
//   const sliceStart = content.indexOf("export const");
//   const sliceEnd = content.indexOf("export function");
//   return content.slice(sliceStart, sliceEnd);
// }

try {
  (async () => {
    await copyAddress();
    // await fs.writeFile(ABI_PATH, await copyABI());
    process.exit(0);
  })();
} catch {
  process.exit(1);
}

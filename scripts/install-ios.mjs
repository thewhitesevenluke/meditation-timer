import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const project = 'ios/App/App.xcodeproj';
const scheme = 'App';
const configuration = 'Debug';
const derivedDataPath = '.build/ios-install';
const appPath = `${derivedDataPath}/Build/Products/Debug-iphoneos/App.app`;
const bundleId = 'com.lukex.goldenmeditation';

function run(command, args, options = {}) {
  console.log(`$ ${command} ${args.join(' ')}`);
  const result = spawnSync(command, args, {
    stdio: options.capture ? ['ignore', 'pipe', 'pipe'] : 'inherit',
    encoding: 'utf8',
  });

  if (result.status !== 0) {
    if (options.capture) {
      process.stdout.write(result.stdout ?? '');
      process.stderr.write(result.stderr ?? '');
    }
    throw new Error(`${command} failed with exit code ${result.status}`);
  }

  return result.stdout ?? '';
}

function jsonFromDeviceCtl(args) {
  const dir = mkdtempSync(join(tmpdir(), 'golden-meditation-'));
  const output = join(dir, 'devicectl.json');
  run('xcrun', ['devicectl', ...args, '--json-output', output], { capture: true });
  return JSON.parse(readFileSync(output, 'utf8'));
}

function findDevice() {
  const data = jsonFromDeviceCtl(['list', 'devices']);
  const devices = data.result?.devices ?? [];
  const available = devices.filter((device) => {
    const name = device.deviceProperties?.name ?? '';
    const platform = device.hardwareProperties?.platform ?? '';
    const pairingState = device.connectionProperties?.pairingState ?? '';
    const bootState = device.deviceProperties?.bootState ?? '';
    return platform === 'iOS' && pairingState === 'paired' && bootState === 'booted' && name;
  });

  if (available.length === 0) {
    throw new Error('No available iPhone was found. Connect and unlock your iPhone, then trust this Mac.');
  }

  if (available.length > 1) {
    console.log('Multiple iPhones found; using the first one:');
  }

  const device = available[0];
  return {
    id: device.identifier,
    name: device.deviceProperties?.name ?? device.identifier,
  };
}

try {
  const device = findDevice();
  console.log(`Installing on ${device.name} (${device.id})`);

  run('xcodebuild', [
    '-project',
    project,
    '-scheme',
    scheme,
    '-configuration',
    configuration,
    '-destination',
    `platform=iOS,id=${device.id}`,
    '-derivedDataPath',
    derivedDataPath,
    '-allowProvisioningUpdates',
    '-allowProvisioningDeviceRegistration',
    'build',
  ]);

  run('xcrun', ['devicectl', 'device', 'install', 'app', '--device', device.id, appPath]);

  try {
    run('xcrun', ['devicectl', 'device', 'process', 'launch', '--device', device.id, bundleId]);
  } catch (error) {
    console.log('');
    console.log('Installed, but iOS refused to launch it automatically.');
    console.log('If this is a trust issue, open Settings > General > VPN & Device Management and trust the developer profile.');
    process.exitCode = 0;
  }
} catch (error) {
  console.error('');
  console.error(error.message);
  process.exit(1);
}

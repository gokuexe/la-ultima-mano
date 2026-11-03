const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync('web/portal-bridge.js', 'utf8');
function environment(id) {
  const scripts = [];
  const window = {LAST_HAND_CONFIG:{gameId:id}};
  vm.runInNewContext(source,{window, document:{createElement:() => ({}), head:{appendChild:s => scripts.push(s)}}});
  return {window,scripts};
}
{
  const {window,scripts}=environment('');
  assert.equal(window.lastHandPortal.ready,false);
  assert.equal(window.lastHandPortal.showAd(),false);
  assert.equal(scripts.length,0);
}
{
  const {window,scripts}=environment('public-id');
  const events=[]; let count=0;
  assert.equal(scripts[0].src,'https://api.gamemonetize.com/sdk.js');
  window.lastHandPortal.setHandler(event => events.push(event));
  window.sdk={showBanner:() => count++};
  assert.equal(window.lastHandPortal.showAd(),false);
  window.SDK_OPTIONS.onEvent({name:'SDK_READY'});
  assert.equal(window.lastHandPortal.showAd(),true);
  assert.equal(window.lastHandPortal.showAd(),false);
  assert.equal(count,1);
  window.SDK_OPTIONS.onEvent({name:'SDK_GAME_PAUSE'});
  const late=[]; window.lastHandPortal.setHandler(event => late.push(event));
  assert.deepEqual(late,['SDK_GAME_PAUSE']);
  window.SDK_OPTIONS.onEvent({name:'SDK_GAME_START'});
  assert.equal(window.lastHandPortal.showAd(),true);
  window.SDK_OPTIONS.onEvent({name:'SDK_GAME_START'});
  window.sdk.showBanner=() => {throw new Error('blocked');};
  assert.equal(window.lastHandPortal.showAd(),false);
  assert.deepEqual(events,['SDK_READY','SDK_GAME_PAUSE']);
}
console.log('Portal bridge: configuration, SDK events, duplicate requests and blocked ads OK');

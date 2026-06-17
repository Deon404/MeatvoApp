/**
 * Test script for zone-splitter K-means clustering
 */

const {
  splitOrdersIntoZones,
  optimizeMultiRiderRoute,
  avg,
  pickRandomCentroids,
  findNearestCentroidIndex,
  balanceZones,
} = require('../../src/modules/delivery/zone-splitter');

console.log('Zone splitter tests\n');

let passed = 0;
let failed = 0;

function assert(label, condition) {
  if (condition) {
    passed += 1;
    console.log(`PASS: ${label}`);
  } else {
    failed += 1;
    console.error(`FAIL: ${label}`);
  }
}

// Test 1: avg function
assert('avg', avg([1, 2, 3, 4, 5]) === 3);
const sampleOrders = [
  { orderId: 1, lat: 23.65, lng: 86.17, customerName: 'Alice', address: '123 Main St' },
  { orderId: 2, lat: 23.66, lng: 86.18, customerName: 'Bob', address: '456 Oak Ave' },
  { orderId: 3, lat: 23.67, lng: 86.19, customerName: 'Charlie', address: '789 Pine Rd' },
  { orderId: 4, lat: 23.68, lng: 86.20, customerName: 'Diana', address: '321 Elm St' },
  { orderId: 5, lat: 23.70, lng: 86.22, customerName: 'Eve', address: '654 Maple Dr' },
  { orderId: 6, lat: 23.72, lng: 86.24, customerName: 'Frank', address: '987 Cedar Ln' },
  { orderId: 7, lat: 23.64, lng: 86.16, customerName: 'Grace', address: '147 Birch Way' },
  { orderId: 8, lat: 23.66, lng: 86.17, customerName: 'Hank', address: '258 Willow Ct' },
];

const zones = splitOrdersIntoZones(sampleOrders, 2);
assert('splitOrdersIntoZones count', zones.length === 2);
const totalOrdersInZones = zones.reduce((sum, zone) => sum + zone.orders.length, 0);
assert('all orders assigned', totalOrdersInZones === sampleOrders.length);

// Test 3: optimizeMultiRiderRoute
const storeLat = 23.6583;
const storeLng = 86.1764;
const numRiders = 3;

const multiRiderPlan = optimizeMultiRiderRoute(sampleOrders, numRiders, storeLat, storeLng);
assert('multiRiderPlan totalOrders', multiRiderPlan.totalOrders === sampleOrders.length);
assert('multiRiderPlan zones', multiRiderPlan.zones.length <= numRiders);

// Test 4: Edge case - more riders than orders
const fewOrders = sampleOrders.slice(0, 2);
const manyRiders = 5;
const edgePlan = optimizeMultiRiderRoute(fewOrders, manyRiders, storeLat, storeLng);
assert('more riders than orders', edgePlan.zones.length === fewOrders.length);

const emptyPlan = optimizeMultiRiderRoute([], 2, storeLat, storeLng);
assert('empty orders', emptyPlan.zones.length === 0);

const unbalancedZones = [
  [
    { orderId: 1, lat: 23.65, lng: 86.17 },
    { orderId: 2, lat: 23.66, lng: 86.18 },
    { orderId: 3, lat: 23.67, lng: 86.19 },
    { orderId: 4, lat: 23.68, lng: 86.20 },
    { orderId: 5, lat: 23.70, lng: 86.22 },
    { orderId: 6, lat: 23.72, lng: 86.24 },
    { orderId: 7, lat: 23.64, lng: 86.16 },
    { orderId: 8, lat: 23.66, lng: 86.17 },
  ],
  [
    { orderId: 9, lat: 23.61, lng: 86.15 },
    { orderId: 10, lat: 23.62, lng: 86.16 },
  ],
];

const balanced = balanceZones(unbalancedZones, 2);
assert('balanceZones length', balanced.length === 2);

console.log(`\nSummary: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);

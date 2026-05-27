// Task 1: Emergency Fuel Report
// Find all vehicles "In Transit" with fuelLevel below 50%
db.vehicles.aggregate([
  {
    $match: {
      status: "In Transit",
      fuelLevel: { $lt: 50 }
    }
  },
  {
    $project: {
      _id: 0,
      vin: 1,
      type: 1,
      fuelLevel: 1
    }
  }
]);

// Task 2: Maintenance Prioritization
// Find vehicles in Maintenance, rename activeAlerts to issues, sort oldest first
db.vehicles.aggregate([
  {
    $match: {
      status: "Maintenance"
    }
  },
  {
    $project: {
      _id: 0,
      vin: 1,
      issues: "$activeAlerts",
      lastServiceDate: 1
    }
  },
  {
    $sort: {
      lastServiceDate: 1
    }
  }
]);

// Task 3: Electric Fleet Geo-Audit
// Find all electric vehicles and extract lon/lat from coordinates array
db.vehicles.aggregate([
  {
    $match: {
      isElectric: true
    }
  },
  {
    $project: {
      _id: 0,
      vin: 1,
      lon: { $arrayElemAt: ["$location.coordinates", 0] },
      lat: { $arrayElemAt: ["$location.coordinates", 1] }
    }
  }
]);

// Task 4: High-Risk Truck Report
// Find top 3 Semi-Trucks by alert count with urgent refuel flag
db.vehicles.aggregate([
  {
    $match: {
      type: "Semi-Truck"
    }
  },
  {
    $addFields: {
      alertCount: { $size: { $ifNull: ["$activeAlerts", []] } },
      needsUrgentRefuel: { $lt: ["$fuelLevel", 20] }
    }
  },
  {
    $project: {
      _id: 0,
      vin: 1,
      alertCount: 1,
      needsUrgentRefuel: 1
    }
  },
  {
    $sort: {
      alertCount: -1
    }
  },
  {
    $limit: 3
  }
]);
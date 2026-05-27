//TASK 1: Find all vehicles that are currently "In Transit" and have a fuel level below 50%. Return the VIN, type, and fuel level of these vehicles.
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

//TASK 2: Identify all vehicles that are currently under "Maintenance" and have active alerts. Return the VIN, list of active alerts, and the date of the last service for these vehicles, sorted by the last service date in ascending order.
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

//TASK 3: Retrieve the VIN, longitude, and latitude of all electric vehicles. The location is stored as a GeoJSON point in the "location" field, where "coordinates" is an array with longitude at index 0 and latitude at index 1.
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

//TASK 4: Find the top 3 semi-trucks with the highest number of active alerts. Return the VIN, the count of active alerts, and a boolean indicating whether the truck needs urgent refueling (fuel level below 20%).
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
//task1
db.sales.aggregate([
  {
    $group: {
      _id: "$branch",
      totalRevenue: { $sum: "$total" },
      averageRating: { $avg: "$rating" },
      transactionCount: { $sum: 1 }
    }
  }
]);

//task2
db.sales.aggregate([
  {
    $group: {
      _id: "$productLine",
      minUnitPrice: { $min: "$unitPrice" },
      maxUnitPrice: { $max: "$unitPrice" },
      avgQuantity: { $avg: "$quantity" }
    }
  }
]);

//task3
db.sales.aggregate([
  {
    $group: {
      _id: { b: "$branch", g: "$gender" },
      totalSales: { $sum: "$total" }
    }
  }
]);

//task4
db.sales.aggregate([
  {
    $match: { customerType: "Member" }
  },
  {
    $group: {
      _id: "$city",
      uniqueProductLines: { $addToSet: "$productLine" },
      allPaymentMethods: { $push: "$payment" }
    }
  }
]);

//task5
db.sales.aggregate([
  {
    $group: {
      _id: null,
      totalRevenue: { $sum: "$total" },
      totalQuantitySold: { $sum: "$quantity" }
    }
  }
]);
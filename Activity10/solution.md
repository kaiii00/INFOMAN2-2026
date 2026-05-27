# Activity 10 Solution


## Part 1: Quick Mapping (Postgres -> MongoDB)

| PostgreSQL | MongoDB Equivalent |
|---|---|
| `INSERT INTO posts ...` | `db.posts.insertOne({...})` |
| `SELECT * FROM posts WHERE title='...'` | `db.posts.find({title: "..."})` |
| `UPDATE posts SET title='...' WHERE id=...` | `db.posts.updateOne({_id: ...}, {$set: {title: "..."}})` |
| `DELETE FROM posts WHERE id=...` | `db.posts.deleteOne({_id: ...})` |

## Part 2: Hands-on CRUD in MongoDB

Write the commands you executed and paste screenshots from Mongo shell after each command/block.

### 2.1 Setup

Commands:

```javascript

use devstream_db
db.posts.drop()

db.posts.insertOne({
    _id: 1,
    title: "Mastering MongoDB for Postgres Devs",
    content: "Intro guide",
    author_username: "db_wizard",
    category: "database",
    views: 10
})

```

Screenshot(s):
- ![](/activity10/images/setup.png)

### 2.2 Create

Commands:

```javascript

db.posts.insertOne({
|   _id: 2,
|   title: "Learning MongoDB CRUD Operations",
|   content: "MongoDB practice",
|   author_username: "db_jas",
|   category: "technology",
|   views: 5
| })

```

Screenshot(s):
- ![](/activity10/images/create.png)

### 2.3 Read

Commands:

```javascript
db.posts.find()

db.posts.find({ _id: 1 })

db.posts.find({}, { title: 1, author_username: 1, _id: 0 })
```

Screenshot(s):
- ![](/activity10/images/findAllPosts.png)
- ![](/activity10/images/resultFor_id 1.png)
- ![](/activity10/images/titleAndAuthor_Username.png)

### 2.4 Update

Commands:

```javascript
db.posts.updateOne(
  { _id: 1 },
  { $set: { title: "MongoDB CRUD Basics" } }
)

db.posts.updateOne(
  { _id: 1 },
  { $inc: { views: 1 } }
)

db.posts.updateMany(
  {},
  { $set: { status: "published" } }
)
```

Screenshot(s):
- ![](/activity10/images/changeTitleOf_id1.png)
- ![](/activity10/images/IncreaseViewsBy1.png)
- ![](/activity10/images/addStatusToAllPosts.png)


### 2.5 Delete

Commands:

```javascript
db.posts.deleteOne({ _id: 2 })
```

Screenshot(s):
- ![](/activity10/images/delete_Id2.png)

## Part 3: Reflection (3-4 sentences)

1. One thing that feels easier in MongoDB CRUD:

One thing that feels easier in MongoDB CRUD is the flexibility of documents because fields can be added without changing the schema. Updating data is also simple using operators like $set and $inc.

2. One thing that was clearer in PostgreSQL CRUD:

PostgreSQL CRUD feels clearer when handling structured relational data because tables and SQL syntax are very organized. Relationships between records are also easier to understand using joins and foreign keys.


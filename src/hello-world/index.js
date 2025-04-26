const express = require('express');
const app = express();
const port = 3000;

// Middleware to parse JSON bodies
app.use(express.json());

// Simulating an in-memory data store
let users = [
  { id: 1, name: 'John Doe', age: 30 },
  { id: 2, name: 'Jane Doe', age: 25 },
];

// **Create** - Add a new user
app.post('/users', (req, res) => {
  const { name, age } = req.body;
  
  if (!name || !age) {
    return res.status(400).json({ error: 'Name and age are required' });
  }

  const newUser = { id: users.length + 1, name, age };
  users.push(newUser);
  
  res.status(201).json(newUser);
});

// **Read** - Get all users
app.get('/users', (req, res) => {
  res.status(200).json(users);
});

// **Read** - Get a user by ID
app.get('/users/:id', (req, res) => {
  const { id } = req.params;
  const user = users.find(u => u.id === parseInt(id));

  if (!user) {
    return res.status(404).json({ error: 'User not found' });
  }

  res.status(200).json(user);
});

// **Update** - Update a user by ID
app.put('/users/:id', (req, res) => {
  const { id } = req.params;
  const { name, age } = req.body;
  
  const user = users.find(u => u.id === parseInt(id));

  if (!user) {
    return res.status(404).json({ error: 'User not found' });
  }

  user.name = name || user.name;
  user.age = age || user.age;

  res.status(200).json(user);
});

// **Delete** - Delete a user by ID
app.delete('/users/:id', (req, res) => {
  const { id } = req.params;
  const userIndex = users.findIndex(u => u.id === parseInt(id));

  if (userIndex === -1) {
    return res.status(404).json({ error: 'User not found' });
  }

  users.splice(userIndex, 1);
  res.status(204).send(); // No content, just deletes the resource
});

// Home route
app.get('/', (req, res) => {
  res.send('Hello World!');
});

// Start the server
app.listen(port, () => {
  console.log(`Access your application at http://localhost:${port}`);
});

module.exports = app;

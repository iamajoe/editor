/**
 * A JavaScript Test Fixture for Editor & Parser Testing
 * This file contains various JavaScript constructs for testing purposes.
 */

// Long line test
const longString =
  "This is a very long string that should test line wrapping behavior in text editors. It contains various elements such as numbers 1234567890, special characters !@#$%^&*(), and even some unicode symbols like α, β, γ.";

// Multiline template literal
const multiLineString = `
    This is a multi-line
    string using template
    literals in JavaScript.
`;

// Arrow functions
const add = (a, b) => a + b;
const complexArrow = (x, y) => {
  return x * y + Math.random();
};

// Normal function
function multiply(a, b) {
  return a * b;
}

// Default parameters & rest operator
function greet(name = "User", ...messages) {
  return `Hello ${name}, ${messages.join(" ")}`;
}

// Object & Array Destructuring
const person = { name: "Alice", age: 25, location: "NY" };
const { name, age } = person;

const numbers = [1, 2, 3, 4, 5];
const [first, second, ...rest] = numbers;

// Spread operator
const copyPerson = { ...person, profession: "Engineer" };
const newNumbers = [...numbers, 6, 7, 8];

// Class & Inheritance
class Animal {
  constructor(name) {
    this.name = name;
  }
  speak() {
    console.log(`${this.name} makes a noise.`);
  }
}

class Dog extends Animal {
  speak() {
    console.log(`${this.name} barks.`);
  }
}

const dog = new Dog("Rex");
dog.speak();

// Promises & Async/Await
const fetchData = () => {
  return new Promise((resolve) => {
    setTimeout(() => resolve("Data received!"), 1000);
  });
};

async function getData() {
  const data = await fetchData();
  console.log(data);
}
getData();

// Regular Expressions
const regex = /hello\s(world)/gi;
const result = regex.test("Hello World");
console.log("Regex match:", result);

// JSON Parsing
const jsonString = '{"name":"Alice","age":25}';
const parsedJSON = JSON.parse(jsonString);
console.log(parsedJSON);

// DOM Manipulation (if running in a browser environment)
if (typeof document !== "undefined") {
  const div = document.createElement("div");
  div.textContent = "Hello, world!";
  document.body.appendChild(div);
}

// Event Listener
if (typeof window !== "undefined") {
  window.addEventListener("click", () => console.log("Window clicked!"));
}

// Export & Import (ES6 Modules)
export function exportedFunction() {
  return "This is an exported function";
}

export default class ExportedClass {
  constructor() {
    this.message = "Exported class instance";
  }
}

// Immediately Invoked Function Expression (IIFE)
(function () {
  console.log("IIFE executed");
})();

// Error handling with try/catch
try {
  throw new Error("This is a test error");
} catch (error) {
  console.error("Caught an error:", error.message);
}

// Map, Filter, Reduce
const mappedNumbers = numbers.map((n) => n * 2);
const filteredNumbers = numbers.filter((n) => n % 2 === 0);
const reducedValue = numbers.reduce((acc, curr) => acc + curr, 0);

console.log({ mappedNumbers, filteredNumbers, reducedValue });

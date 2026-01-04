# Api Craft

**Api Craft** is a powerful, developer-centric API client designed as a modern alternative to Postman, Insomnia, and Yaak. Built with Flutter, it focuses on performance, privacy, and a seamless developer experience with a hybrid storage model.

![preview](./images/preview.png)

## 🚀 Key Features

### 📡 Protocols & Request Types
- **HTTP/HTTPS**: Full support for RESTful APIs with all standard methods (GET, POST, PUT, DELETE, PATCH, etc.).
- **WebSocket**: Real-time WebSocket testing with message history, active connection management, and message composition.
- **GraphQL**: Native GraphQL support with syntax highlighting, query/mutation support, and variable management.
- **gRPC**: (Coming Soon)

### 📦 Collection & Organization
- **Hybrid Storage Architecture**:
  - **Git-Friendly**: Requests, Folders, and Shared Environments are stored as human-readable JSON files, making them perfect for version control (Git).
  - **Local Privacy**: History, Cookies, and Private Environments are stored in a local SQLite database, ensuring sensitive data doesn't accidentally get committed.
- **Filesystem Collections**: Open any folder on your machine as a collection.
- **Nested Organization**: organize requests into deeply nested folders.

### ⚡ Dynamic Environments & Variables
- **Environment Management**: Create unlimited environments (Dev, Staging, Prod).
- **Global Variables**: Define variables accessible across all requests.
- **Shared vs. Private**: 
  - **Shared Environments**: Saved as files to share with your team.
  - **Private Environments**: Saved locally in the DB for sensitive keys/secrets.
- **Recursive Resolution**: Variables can reference other variables.

### 🔮 Template Functions & Scripting
Power up your requests with dynamic values and automation.

**Template Functions** (Insert dynamic data anywhere):
- `response.body.path`: Extract values from previous responses (JSONPath/XPath).
- `response.header`: Use headers from previous responses.
- `cookie.value`: Access values from the cookie jar.
- `prompt.text`: Prompt the user for input at runtime.
- `uuid`: Generate random UUIDs.
- `timestamp`: Insert current timestamps.
- `regex.match` / `regex.replace`: Process strings dynamically.

**Scripting (JavaScript)**:
- **Pre-Request Scripts**: Modify requests before they are sent.
- **Post-Request Scripts**: Run assertions, chain requests, or save variables from responses.
- Full access to the request/response context.

### 🍪 Cookie Management
- **Automatic Cookie Jar**: Cookies are automatically captured and stored from responses.
- **Per-Collection Jars**: Multiple cookie jars to isolate sessions (e.g., standard vs. admin users).

### 🛠 Developer Experience
- **Request Chaining**: Use values from one request in the next automatically.
- **Fast Response Viewing**: Syntax highlighting for JSON, XML, HTML, and more.
- **Privacy Focused**: No cloud sync. Your data stays on your machine.

## 📸 Screenshots

<details>
<summary><b>Template Functions</b></summary>
<img src="./images/template-fn.png" alt="Template Functions" width="600"/>
</details>


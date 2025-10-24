
# 🌱 Transparent Fair-Trade Supply Chain Tracking

A blockchain-based solution for tracking ethical sourcing of products from farm to shelf, built on the Stacks blockchain using Clarity smart contracts.

## 🎯 Problem & Solution

**Problem**: Consumers can't verify the ethical sourcing of products they purchase.

**Solution**: A Clarity-based DApp that tracks goods (coffee, cocoa, etc.) through every stage of the supply chain, ensuring transparency and fair-trade compliance.

## ✨ Features

- 🏭 **Producer Registration**: Register and certify fair-trade producers
- 📜 **Certification Management**: Issue and track fair-trade certifications
- 📦 **Product Creation**: Create trackable product batches with fair-trade premiums
- 🔗 **Supply Chain Tracking**: Track products through multiple stages (farm → processing → shipping → retail)
- ✅ **Stage Verification**: Authorized handlers can verify each supply chain stage
- 🔐 **Custody Transfer**: Secure transfer of product custody between handlers
- 🔍 **Full Traceability**: Complete product journey visibility for consumers

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js and npm for testing

### Installation

1. Clone the repository:
```bash
git clone https://github.com/Dezell234/Transparent-Fair-Trade-Supply-Chain-Tracking.git
cd Transparent-Fair-Trade-Supply-Chain-Tracking
```

2. Install dependencies:
```bash
npm install
```

3. Run tests:
```bash
npm test
```

## 📋 Contract Functions

### 🔓 Public Functions

| Function | Description | Access |
|----------|-------------|---------|
| `register-producer` | Register a new fair-trade producer | Owner only |
| `add-certification` | Add certification to a producer | Owner only |
| `create-product` | Create a new trackable product batch | Producer only |
| `authorize-handler` | Authorize supply chain handlers | Owner only |
| `revoke-handler` | Revoke handler authorization | Owner only |
| `update-supply-chain-stage` | Add new stage to product journey | Current holder/Handler |
| `verify-stage` | Verify a supply chain stage | Authorized handlers |
| `link-product-certification` | Link certification to product | Auto-validated |
| `transfer-custody` | Transfer product custody | Current holder |

### 📖 Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-producer` | Get producer information |
| `get-product` | Get product details |
| `get-certification` | Get certification details |
| `get-supply-chain-stage` | Get specific stage information |
| `get-product-trace` | Get complete product journey |
| `is-handler-authorized` | Check if handler is authorized |
| `is-product-certified` | Check product certification link |

## 🔧 Usage Examples

### 1. 🏭 Register a Producer
```clarity
(contract-call? .transparent-trade-tracking register-producer 
    "Green Coffee Farm" 
    "Colombia, Huila Region" 
    'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### 2. 📜 Add Fair-Trade Certification
```clarity
(contract-call? .transparent-trade-tracking add-certification 
    u1 
    "Fair Trade Certified" 
    "Fair Trade USA" 
    u52560) ;; Valid for ~1 year
```

### 3. 📦 Create Product Batch
```clarity
(contract-call? .transparent-trade-tracking create-product 
    u1 
    "Arabica Coffee" 
    "BATCH-2024-001" 
    u1000 
    u50) ;; 50 STX fair-trade premium
```

### 4. 🔗 Track Supply Chain Stage
```clarity
(contract-call? .transparent-trade-tracking update-supply-chain-stage 
    u1 
    "Processing" 
    "Bogota Processing Facility" 
    "Beans washed and dried")
```

### 5. ✅ Verify Stage
```clarity
(contract-call? .transparent-trade-tracking verify-stage u1 u1)
```

### 6. 🔍 Get Complete Product Trace
```clarity
(contract-call? .transparent-trade-tracking get-product-trace u1)
```

## 🏗️ Contract Architecture

The contract uses several key data structures:

### 📊 Data Maps

- **🏭 Producers**: Store producer information and certification status
- **📜 Certifications**: Track fair-trade certifications with validity periods  
- **📦 Products**: Store product batches with current stage and holder
- **🔗 Supply Chain Stages**: Track each step in the product journey
- **👥 Authorized Handlers**: Manage who can verify stages
- **🔗 Product Certifications**: Link products to their certifications

### 🔢 Data Variables

- `next-product-id`: Auto-incrementing product identifier
- `next-producer-id`: Auto-incrementing producer identifier
- `next-certification-id`: Auto-incrementing certification identifier

### ⚠️ Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | `err-owner-only` | Function restricted to contract owner |
| u101 | `err-not-found` | Requested item not found |
| u102 | `err-unauthorized` | Caller not authorized for action |
| u103 | `err-invalid-stage` | Invalid supply chain stage |
| u104 | `err-already-exists` | Item already exists |
| u105 | `err-invalid-input` | Invalid input parameters |

## 🌊 Supply Chain Flow

```
🌱 Farm → 🏭 Processing → 📦 Packaging → 🚚 Shipping → 🏪 Retail → 👤 Consumer
   ↓         ↓            ↓           ↓          ↓
  ✅ Verify  ✅ Verify    ✅ Verify   ✅ Verify  ✅ Verify
```

Each stage can be:
- 📝 **Recorded** by current holder
- ✅ **Verified** by authorized handlers
- 🔍 **Traced** by consumers

## 🧪 Testing

Run the test suite:

```bash
npm test
```

Tests cover:
- ✅ Producer registration and certification
- ✅ Product creation and tracking
- ✅ Supply chain stage management
- ✅ Authorization and access control
- ✅ Error handling and edge cases

## 🔒 Security Features

- 👑 **Owner Controls**: Critical functions restricted to contract owner
- 🔐 **Access Control**: Role-based permissions for different actors
- ✅ **Input Validation**: Comprehensive input sanitization
- 🛡️ **Authorization Checks**: Multi-level authorization system

## 🌍 Real-World Applications

- ☕ **Coffee Supply Chain**: Track coffee from bean to cup
- 🍫 **Cocoa Tracking**: Ensure ethical chocolate sourcing  
- 🌾 **Agricultural Products**: Verify organic and fair-trade claims
- 💎 **Luxury Goods**: Authenticate high-value items
- 🏥 **Pharmaceuticals**: Track medicine authenticity

## 🤝 Contributing

1. 🍴 Fork the repository
2. 🌿 Create a feature branch (`git checkout -b feature/amazing-feature`)
3. ✨ Make your changes
4. 🧪 Add tests for new functionality
5. 📝 Commit your changes (`git commit -m 'Add amazing feature'`)
6. 🚀 Push to the branch (`git push origin feature/amazing-feature`)
7. 🔄 Submit a pull request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🌟 Future Enhancements

- 📱 Mobile app for QR code scanning
- 🌐 Web dashboard for supply chain visualization
- 🔔 Real-time notifications for stage updates
- 📊 Analytics and reporting features
- 🌍 Multi-language support
- 🔗 Integration with IoT sensors
- 💰 Automated fair-trade premium distribution

## 📞 Support

- 📧 Email: support@transparenttrade.com
- 💬 Discord: [Join our community](https://discord.gg/transparenttrade)
- 📖 Documentation: [docs.transparenttrade.com](https://docs.transparenttrade.com)
- 🐛 Issues: [GitHub Issues](https://github.com/Dezell234/Transparent-Fair-Trade-Supply-Chain-Tracking/issues)

---

Made with ❤️ for ethical trade and blockchain transparency 🌱✨


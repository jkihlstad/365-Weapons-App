//
//  ModelTests.swift
//  365WeaponsAdminTests
//
//  Comprehensive tests for data models
//

import XCTest
@testable import _65WeaponsAdmin

final class ModelTests: XCTestCase {

    // MARK: - Setup/Teardown

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Product Tests

    func test_product_formattedPrice_validPrice_returnsFormattedString() {
        let product = Product(
            id: "test-id",
            title: "Test Product",
            description: "Description",
            price: 99.99,
            priceRange: nil,
            category: "Test",
            image: "/test.jpg",
            stripeProductId: nil,
            stripePriceId: nil,
            inStock: true,
            hasOptions: false,
            createdAt: Date()
        )

        XCTAssertEqual(product.formattedPrice, "$99.99")
    }

    func test_product_formattedPrice_withPriceRange_returnsPriceRange() {
        let product = Product(
            id: "test-id",
            title: "Test Product",
            description: nil,
            price: 0,
            priceRange: "$50 - $100",
            category: "Test",
            image: "/test.jpg",
            stripeProductId: nil,
            stripePriceId: nil,
            inStock: true,
            hasOptions: true,
            createdAt: Date()
        )

        XCTAssertEqual(product.formattedPrice, "$50 - $100")
    }

    func test_product_formattedPrice_zeroPrice_returnsZeroFormatted() {
        let product = Product(
            id: "test-id",
            title: "Free Item",
            description: nil,
            price: 0,
            priceRange: nil,
            category: "Test",
            image: "/test.jpg",
            stripeProductId: nil,
            stripePriceId: nil,
            inStock: true,
            hasOptions: false,
            createdAt: Date()
        )

        XCTAssertEqual(product.formattedPrice, "$0.00")
    }

    func test_product_formattedPrice_emptyPriceRange_usesPrice() {
        let product = Product(
            id: "test-id",
            title: "Test Product",
            description: nil,
            price: 149.99,
            priceRange: "",
            category: "Test",
            image: "/test.jpg",
            stripeProductId: nil,
            stripePriceId: nil,
            inStock: true,
            hasOptions: false,
            createdAt: Date()
        )

        XCTAssertEqual(product.formattedPrice, "$149.99")
    }

    func test_product_hashable_sameId_areEqual() {
        let product1 = createMockProduct(id: "same-id")
        let product2 = createMockProduct(id: "same-id")

        XCTAssertEqual(product1.hashValue, product2.hashValue)
    }

    func test_product_hashable_differentId_areNotEqual() {
        let product1 = createMockProduct(id: "id-1")
        let product2 = createMockProduct(id: "id-2")

        XCTAssertNotEqual(product1.hashValue, product2.hashValue)
    }

    // MARK: - Product JSON Decoding Tests

    func test_product_jsonDecoding_validJSON_decodesSuccessfully() throws {
        let json = """
        {
            "_id": "prod123",
            "title": "Porting Service",
            "description": "Professional barrel porting",
            "price": 199.99,
            "category": "Services",
            "image": "/images/porting.jpg",
            "inStock": true,
            "hasOptions": true,
            "createdAt": 1704067200000
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let product = try decoder.decode(Product.self, from: data)

        XCTAssertEqual(product.id, "prod123")
        XCTAssertEqual(product.title, "Porting Service")
        XCTAssertEqual(product.description, "Professional barrel porting")
        XCTAssertEqual(product.price, 199.99)
        XCTAssertEqual(product.category, "Services")
        XCTAssertTrue(product.inStock)
        XCTAssertEqual(product.hasOptions, true)
    }

    func test_product_jsonDecoding_nullDescription_decodesAsNil() throws {
        let json = """
        {
            "_id": "prod123",
            "title": "Test Product",
            "description": null,
            "price": 99.99,
            "category": "Test",
            "image": "/test.jpg",
            "inStock": true,
            "createdAt": 1704067200000
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let product = try decoder.decode(Product.self, from: data)

        XCTAssertNil(product.description)
    }

    func test_product_jsonDecoding_missingOptionalFields_decodesSuccessfully() throws {
        let json = """
        {
            "_id": "prod123",
            "title": "Minimal Product",
            "price": 50.00,
            "category": "Test",
            "image": "/test.jpg",
            "inStock": false,
            "createdAt": 1704067200000
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let product = try decoder.decode(Product.self, from: data)

        XCTAssertNil(product.description)
        XCTAssertNil(product.priceRange)
        XCTAssertNil(product.stripeProductId)
        XCTAssertNil(product.stripePriceId)
        XCTAssertNil(product.hasOptions)
    }

    // MARK: - Order Tests

    func test_orderStatus_displayName_returnsCorrectStrings() {
        XCTAssertEqual(OrderStatus.awaitingPayment.displayName, "Awaiting Payment")
        XCTAssertEqual(OrderStatus.awaitingShipment.displayName, "Awaiting Shipment")
        XCTAssertEqual(OrderStatus.inProgress.displayName, "In Progress")
        XCTAssertEqual(OrderStatus.completed.displayName, "Completed")
        XCTAssertEqual(OrderStatus.cancelled.displayName, "Cancelled")
    }

    func test_orderStatus_color_returnsCorrectColors() {
        XCTAssertEqual(OrderStatus.awaitingPayment.color, "orange")
        XCTAssertEqual(OrderStatus.awaitingShipment.color, "blue")
        XCTAssertEqual(OrderStatus.inProgress.color, "purple")
        XCTAssertEqual(OrderStatus.completed.color, "green")
        XCTAssertEqual(OrderStatus.cancelled.color, "red")
    }

    func test_orderStatus_caseIterable_containsAllCases() {
        let allCases = OrderStatus.allCases
        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.awaitingPayment))
        XCTAssertTrue(allCases.contains(.awaitingShipment))
        XCTAssertTrue(allCases.contains(.inProgress))
        XCTAssertTrue(allCases.contains(.completed))
        XCTAssertTrue(allCases.contains(.cancelled))
    }

    // MARK: - Order JSON Decoding Tests

    func test_order_jsonDecoding_validJSON_decodesSuccessfully() throws {
        let json = """
        {
            "_id": "order123",
            "orderNumber": "ORD-12345",
            "placedBy": "CUSTOMER",
            "status": "AWAITING_SHIPMENT",
            "userEmail": "customer@example.com",
            "totals": {
                "subtotal": 19999,
                "tax": 1600,
                "shipping": 500,
                "total": 22099
            },
            "createdAt": 1704067200000
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let order = try decoder.decode(Order.self, from: data)

        XCTAssertEqual(order.id, "order123")
        XCTAssertEqual(order.orderNumber, "ORD-12345")
        XCTAssertEqual(order.placedBy, .customer)
        XCTAssertEqual(order.status, .awaitingShipment)
        XCTAssertEqual(order.userEmail, "customer@example.com")
        XCTAssertEqual(order.totals?.total, 22099)
    }

    func test_order_formattedTotal_validTotals_returnsFormattedString() {
        let order = createMockOrder(totalCents: 15099)
        XCTAssertEqual(order.formattedTotal, "$150.99")
    }

    func test_order_formattedTotal_nilTotals_returnsZero() {
        let order = createMockOrder(totalCents: nil)
        XCTAssertEqual(order.formattedTotal, "$0.00")
    }

    func test_order_customerEmail_withEndCustomerInfo_usesEndCustomerEmail() {
        let customerInfo = CustomerInfo(name: "John Doe", phone: "555-1234", email: "john@example.com")
        let order = createMockOrderWithCustomerInfo(customerInfo: customerInfo, userEmail: "fallback@example.com")
        XCTAssertEqual(order.customerEmail, "john@example.com")
    }

    func test_order_customerEmail_withoutEndCustomerInfo_usesUserEmail() {
        let order = createMockOrderWithCustomerInfo(customerInfo: nil, userEmail: "user@example.com")
        XCTAssertEqual(order.customerEmail, "user@example.com")
    }

    func test_order_customerEmail_noEmails_returnsUnknown() {
        let order = createMockOrderWithCustomerInfo(customerInfo: nil, userEmail: nil)
        XCTAssertEqual(order.customerEmail, "Unknown")
    }

    // MARK: - OrderPlacedBy Tests

    func test_orderPlacedBy_rawValues_areCorrect() {
        XCTAssertEqual(OrderPlacedBy.customer.rawValue, "CUSTOMER")
        XCTAssertEqual(OrderPlacedBy.partner.rawValue, "PARTNER")
    }

    // MARK: - OrderTotals Tests

    func test_orderTotals_jsonDecoding_validJSON_decodesSuccessfully() throws {
        let json = """
        {
            "subtotal": 10000,
            "discountAmount": 1000,
            "tax": 800,
            "shipping": 500,
            "total": 10300
        }
        """

        let data = json.data(using: .utf8)!
        let totals = try JSONDecoder().decode(OrderTotals.self, from: data)

        XCTAssertEqual(totals.subtotal, 10000)
        XCTAssertEqual(totals.discountAmount, 1000)
        XCTAssertEqual(totals.tax, 800)
        XCTAssertEqual(totals.shipping, 500)
        XCTAssertEqual(totals.total, 10300)
    }

    func test_orderTotals_jsonDecoding_nullOptionalFields_decodesSuccessfully() throws {
        let json = """
        {
            "subtotal": 10000,
            "total": 10000
        }
        """

        let data = json.data(using: .utf8)!
        let totals = try JSONDecoder().decode(OrderTotals.self, from: data)

        XCTAssertNil(totals.discountAmount)
        XCTAssertNil(totals.tax)
        XCTAssertNil(totals.shipping)
    }

    // MARK: - Service Type Tests

    func test_serviceType_displayName_returnsCorrectStrings() {
        XCTAssertEqual(ServiceType.porting.displayName, "Porting")
        XCTAssertEqual(ServiceType.opticCut.displayName, "Optic Cut")
        XCTAssertEqual(ServiceType.slideEngraving.displayName, "Slide Engraving")
        XCTAssertEqual(ServiceType.other.displayName, "Other")
    }

    func test_serviceType_icon_returnsCorrectIcons() {
        XCTAssertEqual(ServiceType.porting.icon, "wrench.and.screwdriver")
        XCTAssertEqual(ServiceType.opticCut.icon, "scope")
        XCTAssertEqual(ServiceType.slideEngraving.icon, "pencil.and.scribble")
        XCTAssertEqual(ServiceType.other.icon, "cube")
    }

    func test_serviceType_rawValues_areCorrect() {
        XCTAssertEqual(ServiceType.porting.rawValue, "PORTING")
        XCTAssertEqual(ServiceType.opticCut.rawValue, "OPTIC_CUT")
        XCTAssertEqual(ServiceType.slideEngraving.rawValue, "SLIDE_ENGRAVING")
        XCTAssertEqual(ServiceType.other.rawValue, "OTHER")
    }

    func test_serviceType_caseIterable_containsAllCases() {
        let allCases = ServiceType.allCases
        XCTAssertEqual(allCases.count, 4)
    }

    // MARK: - Commission Tests

    func test_commissionStatus_displayName_returnsCorrectStrings() {
        XCTAssertEqual(CommissionStatus.pending.displayName, "Pending")
        XCTAssertEqual(CommissionStatus.eligible.displayName, "Eligible")
        XCTAssertEqual(CommissionStatus.approved.displayName, "Approved")
        XCTAssertEqual(CommissionStatus.paid.displayName, "Paid")
        XCTAssertEqual(CommissionStatus.voided.displayName, "Voided")
    }

    func test_commissionStatus_color_returnsCorrectColors() {
        XCTAssertEqual(CommissionStatus.pending.color, "orange")
        XCTAssertEqual(CommissionStatus.eligible.color, "blue")
        XCTAssertEqual(CommissionStatus.approved.color, "purple")
        XCTAssertEqual(CommissionStatus.paid.color, "green")
        XCTAssertEqual(CommissionStatus.voided.color, "red")
    }

    func test_commissionStatus_rawValues_areCorrect() {
        XCTAssertEqual(CommissionStatus.pending.rawValue, "PENDING")
        XCTAssertEqual(CommissionStatus.eligible.rawValue, "ELIGIBLE")
        XCTAssertEqual(CommissionStatus.approved.rawValue, "APPROVED")
        XCTAssertEqual(CommissionStatus.paid.rawValue, "PAID")
        XCTAssertEqual(CommissionStatus.voided.rawValue, "VOIDED")
    }

    // MARK: - Commission JSON Decoding Tests

    func test_commission_jsonDecoding_validJSON_decodesSuccessfully() throws {
        let json = """
        {
            "_id": "comm123",
            "partnerStoreId": "partner456",
            "orderId": "order789",
            "orderNumber": "ORD-12345",
            "placedBy": "PARTNER",
            "serviceType": "PORTING",
            "commissionBaseAmount": 200.00,
            "commissionAmount": 20.00,
            "status": "ELIGIBLE",
            "eligibleAt": 1704153600000,
            "createdAt": 1704067200000
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let commission = try decoder.decode(Commission.self, from: data)

        XCTAssertEqual(commission.id, "comm123")
        XCTAssertEqual(commission.partnerStoreId, "partner456")
        XCTAssertEqual(commission.commissionAmount, 20.00)
        XCTAssertEqual(commission.status, .eligible)
        XCTAssertNotNil(commission.eligibleAt)
    }

    func test_commission_formattedAmount_returnsCorrectFormat() {
        let commission = createMockCommission(amount: 125.50)
        XCTAssertEqual(commission.formattedAmount, "$125.50")
    }

    // MARK: - PartnerStore Tests

    func test_partnerStore_formattedCommission_percentage_returnsPercentage() {
        let store = createMockPartnerStore(commissionType: .percentage, commissionValue: 0.10)
        XCTAssertEqual(store.formattedCommission, "10%")
    }

    func test_partnerStore_formattedCommission_flat_returnsDollarAmount() {
        let store = createMockPartnerStore(commissionType: .flat, commissionValue: 25.0)
        XCTAssertEqual(store.formattedCommission, "$25.00")
    }

    func test_partnerStore_formattedCommission_perService_returnsDollarAmount() {
        let store = createMockPartnerStore(commissionType: .perService, commissionValue: 15.0)
        XCTAssertEqual(store.formattedCommission, "$15.00")
    }

    func test_partnerStore_jsonDecoding_validJSON_decodesSuccessfully() throws {
        let json = """
        {
            "_id": "partner123",
            "storeName": "Gun Shop Pro",
            "storeCode": "GSP",
            "active": true,
            "storeContactName": "Jane Smith",
            "storePhone": "555-9876",
            "storeEmail": "info@gunshoppro.com",
            "commissionType": "percentage",
            "commissionValue": 0.12,
            "payoutMethod": "PAYPAL",
            "paypalEmail": "payouts@gunshoppro.com",
            "payoutHoldDays": 30,
            "onboardingComplete": true,
            "createdAt": 1704067200000
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let store = try decoder.decode(PartnerStore.self, from: data)

        XCTAssertEqual(store.id, "partner123")
        XCTAssertEqual(store.storeName, "Gun Shop Pro")
        XCTAssertEqual(store.storeCode, "GSP")
        XCTAssertTrue(store.active)
        XCTAssertEqual(store.commissionType, .percentage)
        XCTAssertEqual(store.commissionValue, 0.12)
    }

    // MARK: - CommissionType Tests

    func test_commissionType_rawValues_areCorrect() {
        XCTAssertEqual(CommissionType.percentage.rawValue, "percentage")
        XCTAssertEqual(CommissionType.flat.rawValue, "flat")
        XCTAssertEqual(CommissionType.perService.rawValue, "perService")
    }

    // MARK: - ServiceInquiry Tests

    func test_serviceInquiry_jsonDecoding_validJSON_decodesSuccessfully() throws {
        let json = """
        {
            "_id": "inq123",
            "customerName": "Bob Wilson",
            "customerEmail": "bob@example.com",
            "customerPhone": "555-4321",
            "serviceType": "PORTING",
            "productSlug": "glock-19-porting",
            "productTitle": "Glock 19 Porting Service",
            "message": "Interested in barrel porting",
            "status": "NEW",
            "quotedAmount": 199.99,
            "createdAt": 1704067200000,
            "updatedAt": 1704153600000
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let inquiry = try decoder.decode(ServiceInquiry.self, from: data)

        XCTAssertEqual(inquiry.id, "inq123")
        XCTAssertEqual(inquiry.customerName, "Bob Wilson")
        XCTAssertEqual(inquiry.status, .new)
        XCTAssertEqual(inquiry.quotedAmount, 199.99)
    }

    func test_serviceInquiry_formattedQuote_withQuote_returnsFormatted() {
        let inquiry = createMockServiceInquiry(quotedAmount: 299.99)
        XCTAssertEqual(inquiry.formattedQuote, "$299.99")
    }

    func test_serviceInquiry_formattedQuote_withoutQuote_returnsNil() {
        let inquiry = createMockServiceInquiry(quotedAmount: nil)
        XCTAssertNil(inquiry.formattedQuote)
    }

    // MARK: - InquiryStatus Tests

    func test_inquiryStatus_displayName_returnsCorrectStrings() {
        XCTAssertEqual(InquiryStatus.new.displayName, "New")
        XCTAssertEqual(InquiryStatus.reviewed.displayName, "Reviewed")
        XCTAssertEqual(InquiryStatus.quoted.displayName, "Quoted")
        XCTAssertEqual(InquiryStatus.invoiceSent.displayName, "Invoice Sent")
        XCTAssertEqual(InquiryStatus.paid.displayName, "Paid")
        XCTAssertEqual(InquiryStatus.inProgress.displayName, "In Progress")
        XCTAssertEqual(InquiryStatus.completed.displayName, "Completed")
        XCTAssertEqual(InquiryStatus.cancelled.displayName, "Cancelled")
    }

    func test_inquiryStatus_rawValues_areCorrect() {
        XCTAssertEqual(InquiryStatus.new.rawValue, "NEW")
        XCTAssertEqual(InquiryStatus.invoiceSent.rawValue, "INVOICE_SENT")
        XCTAssertEqual(InquiryStatus.inProgress.rawValue, "IN_PROGRESS")
    }

    // MARK: - DiscountCode Tests

    func test_discountCode_formattedDiscount_percentage_returnsPercentageOff() {
        let code = createMockDiscountCode(discountType: .percentage, discountValue: 0.15)
        XCTAssertEqual(code.formattedDiscount, "15% off")
    }

    func test_discountCode_formattedDiscount_fixed_returnsDollarOff() {
        let code = createMockDiscountCode(discountType: .fixed, discountValue: 20.0)
        XCTAssertEqual(code.formattedDiscount, "$20.00 off")
    }

    func test_discountCode_jsonDecoding_validJSON_decodesSuccessfully() throws {
        let json = """
        {
            "_id": "disc123",
            "code": "SAVE20",
            "partnerStoreId": "partner456",
            "discountType": "percentage",
            "discountValue": 0.20,
            "usageCount": 15,
            "maxUsage": 100,
            "active": true,
            "expiresAt": 1735689600000,
            "createdAt": 1704067200000
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let code = try decoder.decode(DiscountCode.self, from: data)

        XCTAssertEqual(code.id, "disc123")
        XCTAssertEqual(code.code, "SAVE20")
        XCTAssertEqual(code.discountType, .percentage)
        XCTAssertEqual(code.usageCount, 15)
        XCTAssertEqual(code.maxUsage, 100)
        XCTAssertNotNil(code.expiresAt)
    }

    func test_discountCode_jsonDecoding_nullOptionalFields_decodesSuccessfully() throws {
        let json = """
        {
            "_id": "disc123",
            "code": "FLAT10",
            "discountType": "fixed",
            "discountValue": 10.0,
            "usageCount": 0,
            "active": true,
            "createdAt": 1704067200000
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let code = try decoder.decode(DiscountCode.self, from: data)

        XCTAssertNil(code.partnerStoreId)
        XCTAssertNil(code.maxUsage)
        XCTAssertNil(code.expiresAt)
    }

    // MARK: - Action Type Tests

    func test_actionType_icon_returnsCorrectIcons() {
        XCTAssertEqual(ActionType.pageView.icon, "eye")
        XCTAssertEqual(ActionType.productView.icon, "cube")
        XCTAssertEqual(ActionType.addToCart.icon, "cart.badge.plus")
        XCTAssertEqual(ActionType.checkout.icon, "creditcard")
        XCTAssertEqual(ActionType.purchase.icon, "checkmark.circle")
        XCTAssertEqual(ActionType.inquiry.icon, "questionmark.circle")
        XCTAssertEqual(ActionType.partnerSignup.icon, "person.badge.plus")
        XCTAssertEqual(ActionType.login.icon, "person.crop.circle")
        XCTAssertEqual(ActionType.other.icon, "ellipsis.circle")
    }

    func test_actionType_displayName_returnsCorrectStrings() {
        XCTAssertEqual(ActionType.pageView.displayName, "Page View")
        XCTAssertEqual(ActionType.productView.displayName, "Product View")
        XCTAssertEqual(ActionType.addToCart.displayName, "Add to Cart")
        XCTAssertEqual(ActionType.checkout.displayName, "Checkout")
        XCTAssertEqual(ActionType.purchase.displayName, "Purchase")
        XCTAssertEqual(ActionType.inquiry.displayName, "Inquiry")
        XCTAssertEqual(ActionType.partnerSignup.displayName, "Partner Signup")
        XCTAssertEqual(ActionType.login.displayName, "Login")
        XCTAssertEqual(ActionType.other.displayName, "Other")
    }

    func test_actionType_rawValues_areCorrect() {
        XCTAssertEqual(ActionType.pageView.rawValue, "PAGE_VIEW")
        XCTAssertEqual(ActionType.productView.rawValue, "PRODUCT_VIEW")
        XCTAssertEqual(ActionType.addToCart.rawValue, "ADD_TO_CART")
        XCTAssertEqual(ActionType.checkout.rawValue, "CHECKOUT")
        XCTAssertEqual(ActionType.purchase.rawValue, "PURCHASE")
    }

    func test_actionType_caseIterable_containsAllCases() {
        let allCases = ActionType.allCases
        XCTAssertEqual(allCases.count, 9)
    }

    // MARK: - WebsiteAction Tests

    func test_websiteAction_jsonDecoding_validJSON_decodesSuccessfully() throws {
        let json = """
        {
            "_id": "action123",
            "actionType": "PURCHASE",
            "description": "New order placed - #ORD12345",
            "userId": "user456",
            "userEmail": "buyer@example.com",
            "metadata": {"orderId": "order789", "revenue": "199.99"},
            "timestamp": 1704067200000
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let action = try decoder.decode(WebsiteAction.self, from: data)

        XCTAssertEqual(action.id, "action123")
        XCTAssertEqual(action.actionType, .purchase)
        XCTAssertEqual(action.description, "New order placed - #ORD12345")
        XCTAssertEqual(action.userId, "user456")
        XCTAssertEqual(action.metadata?["revenue"], "199.99")
    }

    func test_websiteAction_jsonDecoding_nullOptionalFields_decodesSuccessfully() throws {
        let json = """
        {
            "_id": "action123",
            "actionType": "PAGE_VIEW",
            "description": "Homepage viewed",
            "timestamp": 1704067200000
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let action = try decoder.decode(WebsiteAction.self, from: data)

        XCTAssertNil(action.userId)
        XCTAssertNil(action.userEmail)
        XCTAssertNil(action.metadata)
    }

    // MARK: - Chat Message Tests

    func test_chatMessage_creation_setsDefaults() {
        let message = ChatMessage(role: .user, content: "Hello")

        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Hello")
        XCTAssertFalse(message.isLoading)
        XCTAssertNotNil(message.id)
        XCTAssertNotNil(message.timestamp)
    }

    func test_chatMessage_equality_sameId_areEqual() {
        let id = UUID()
        let message1 = ChatMessage(id: id, role: .user, content: "Hello")
        let message2 = ChatMessage(id: id, role: .user, content: "Hello")

        XCTAssertEqual(message1, message2)
    }

    func test_chatMessage_equality_differentId_areNotEqual() {
        let message1 = ChatMessage(role: .user, content: "Hello")
        let message2 = ChatMessage(role: .user, content: "Hello")

        XCTAssertNotEqual(message1, message2)
    }

    func test_chatMessage_allRoles_areValid() {
        let userMessage = ChatMessage(role: .user, content: "User message")
        let assistantMessage = ChatMessage(role: .assistant, content: "Assistant message")
        let systemMessage = ChatMessage(role: .system, content: "System message")

        XCTAssertEqual(userMessage.role, .user)
        XCTAssertEqual(assistantMessage.role, .assistant)
        XCTAssertEqual(systemMessage.role, .system)
    }

    func test_chatMessage_loadingState_canBeSet() {
        var message = ChatMessage(role: .assistant, content: "", isLoading: true)
        XCTAssertTrue(message.isLoading)

        message.isLoading = false
        XCTAssertFalse(message.isLoading)
    }

    // MARK: - ChatRole Tests

    func test_chatRole_rawValues_areCorrect() {
        XCTAssertEqual(ChatRole.user.rawValue, "user")
        XCTAssertEqual(ChatRole.assistant.rawValue, "assistant")
        XCTAssertEqual(ChatRole.system.rawValue, "system")
    }

    // MARK: - Address Tests

    func test_address_formatted_allFields_returnsFullAddress() {
        let address = Address(
            street: "123 Main St",
            city: "Portland",
            state: "OR",
            zip: "97201",
            country: "USA"
        )

        XCTAssertEqual(address.formatted, "123 Main St, Portland, OR, 97201, USA")
    }

    func test_address_formatted_missingOptionalFields_excludesMissingFields() {
        let address = Address(
            street: "123 Main St",
            city: "Portland",
            state: nil,
            zip: nil,
            country: nil
        )

        XCTAssertEqual(address.formatted, "123 Main St, Portland")
    }

    func test_address_formatted_emptyFields_excludesEmptyFields() {
        let address = Address(
            street: "123 Main St",
            city: "Portland",
            state: "",
            zip: "97201",
            country: ""
        )

        XCTAssertEqual(address.formatted, "123 Main St, Portland, 97201")
    }

    func test_address_formatted_allNil_returnsEmptyString() {
        let address = Address(
            street: nil,
            city: nil,
            state: nil,
            zip: nil,
            country: nil
        )

        XCTAssertEqual(address.formatted, "")
    }

    func test_address_jsonDecoding_validJSON_decodesSuccessfully() throws {
        let json = """
        {
            "street": "456 Oak Ave",
            "city": "Seattle",
            "state": "WA",
            "zip": "98101",
            "country": "USA"
        }
        """

        let data = json.data(using: .utf8)!
        let address = try JSONDecoder().decode(Address.self, from: data)

        XCTAssertEqual(address.street, "456 Oak Ave")
        XCTAssertEqual(address.city, "Seattle")
        XCTAssertEqual(address.state, "WA")
    }

    // MARK: - CustomerInfo Tests

    func test_customerInfo_jsonDecoding_validJSON_decodesSuccessfully() throws {
        let json = """
        {
            "name": "John Doe",
            "phone": "555-1234",
            "email": "john@example.com"
        }
        """

        let data = json.data(using: .utf8)!
        let info = try JSONDecoder().decode(CustomerInfo.self, from: data)

        XCTAssertEqual(info.name, "John Doe")
        XCTAssertEqual(info.phone, "555-1234")
        XCTAssertEqual(info.email, "john@example.com")
    }

    func test_customerInfo_jsonDecoding_nullFields_decodesAsNil() throws {
        let json = """
        {
            "name": null,
            "phone": null,
            "email": "minimal@example.com"
        }
        """

        let data = json.data(using: .utf8)!
        let info = try JSONDecoder().decode(CustomerInfo.self, from: data)

        XCTAssertNil(info.name)
        XCTAssertNil(info.phone)
        XCTAssertEqual(info.email, "minimal@example.com")
    }

    // MARK: - Dashboard Stats Tests

    func test_dashboardStats_creation_setsAllProperties() {
        let stats = DashboardStats(
            totalRevenue: 10000.0,
            totalOrders: 50,
            totalProducts: 25,
            totalPartners: 10,
            pendingOrders: 5,
            pendingInquiries: 3,
            eligibleCommissions: 500.0,
            revenueGrowth: 12.5,
            orderGrowth: 8.3
        )

        XCTAssertEqual(stats.totalRevenue, 10000.0)
        XCTAssertEqual(stats.totalOrders, 50)
        XCTAssertEqual(stats.totalProducts, 25)
        XCTAssertEqual(stats.totalPartners, 10)
        XCTAssertEqual(stats.pendingOrders, 5)
        XCTAssertEqual(stats.pendingInquiries, 3)
        XCTAssertEqual(stats.eligibleCommissions, 500.0)
        XCTAssertEqual(stats.revenueGrowth, 12.5)
        XCTAssertEqual(stats.orderGrowth, 8.3)
    }

    func test_dashboardStats_jsonDecoding_validJSON_decodesSuccessfully() throws {
        let json = """
        {
            "totalRevenue": 25000.50,
            "totalOrders": 100,
            "totalProducts": 50,
            "totalPartners": 15,
            "pendingOrders": 8,
            "pendingInquiries": 5,
            "eligibleCommissions": 1250.00,
            "revenueGrowth": 15.5,
            "orderGrowth": -2.3
        }
        """

        let data = json.data(using: .utf8)!
        let stats = try JSONDecoder().decode(DashboardStats.self, from: data)

        XCTAssertEqual(stats.totalRevenue, 25000.50)
        XCTAssertEqual(stats.revenueGrowth, 15.5)
        XCTAssertEqual(stats.orderGrowth, -2.3)
    }

    // MARK: - RevenueDataPoint Tests

    func test_revenueDataPoint_creation_generatesUniqueId() {
        let point1 = RevenueDataPoint(date: Date(), revenue: 1000.0, orders: 10)
        let point2 = RevenueDataPoint(date: Date(), revenue: 1000.0, orders: 10)

        XCTAssertNotEqual(point1.id, point2.id)
    }

    func test_revenueDataPoint_jsonDecoding_validJSON_decodesSuccessfully() throws {
        let json = """
        {
            "date": 1704067200000,
            "revenue": 5000.00,
            "orders": 25
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let point = try decoder.decode(RevenueDataPoint.self, from: data)

        XCTAssertEqual(point.revenue, 5000.00)
        XCTAssertEqual(point.orders, 25)
        XCTAssertNotNil(point.id)
    }

    // MARK: - AdminUser Tests

    func test_adminUser_displayName_withName_returnsName() {
        let user = AdminUser(
            id: "user123",
            email: "admin@example.com",
            name: "John Admin",
            avatarUrl: nil
        )

        XCTAssertEqual(user.displayName, "John Admin")
    }

    func test_adminUser_displayName_withoutName_returnsEmailPrefix() {
        let user = AdminUser(
            id: "user123",
            email: "admin@example.com",
            name: nil,
            avatarUrl: nil
        )

        XCTAssertEqual(user.displayName, "admin")
    }

    func test_adminUser_displayName_emptyEmail_returnsEmptyString() {
        let user = AdminUser(
            id: "user123",
            email: "",
            name: nil,
            avatarUrl: nil
        )

        // When email is empty, components(separatedBy:) returns empty string, not nil
        XCTAssertEqual(user.displayName, "")
    }

    // MARK: - CreateProductRequest Tests

    func test_createProductRequest_creation_setsAllProperties() {
        let request = CreateProductRequest(
            title: "New Product",
            description: "A great product",
            price: 49.99,
            priceRange: nil,
            category: "Accessories",
            image: "/images/new.jpg",
            inStock: true,
            hasOptions: false
        )

        XCTAssertEqual(request.title, "New Product")
        XCTAssertEqual(request.description, "A great product")
        XCTAssertEqual(request.price, 49.99)
        XCTAssertNil(request.priceRange)
        XCTAssertEqual(request.category, "Accessories")
        XCTAssertTrue(request.inStock)
        XCTAssertFalse(request.hasOptions ?? true)
    }

    func test_createProductRequest_jsonEncoding_encodesCorrectly() throws {
        let request = CreateProductRequest(
            title: "Test",
            description: nil,
            price: 100.0,
            priceRange: nil,
            category: "Test",
            image: "/test.jpg",
            inStock: true,
            hasOptions: nil
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(CreateProductRequest.self, from: data)

        XCTAssertEqual(decoded.title, request.title)
        XCTAssertEqual(decoded.price, request.price)
    }

    // MARK: - UpdateOrderStatusRequest Tests

    func test_updateOrderStatusRequest_jsonEncoding_encodesCorrectly() throws {
        let request = UpdateOrderStatusRequest(
            orderId: "order123",
            status: "COMPLETED"
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: String]

        XCTAssertEqual(json?["orderId"], "order123")
        XCTAssertEqual(json?["status"], "COMPLETED")
    }

    // MARK: - ConvexResponse Tests

    func test_convexResponse_jsonDecoding_withData_decodesSuccessfully() throws {
        let json = """
        {
            "data": ["item1", "item2"],
            "error": null
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ConvexResponse<[String]>.self, from: data)

        XCTAssertEqual(response.data?.count, 2)
        XCTAssertNil(response.error)
    }

    func test_convexResponse_jsonDecoding_withError_decodesSuccessfully() throws {
        let json = """
        {
            "data": null,
            "error": "Something went wrong"
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ConvexResponse<[String]>.self, from: data)

        XCTAssertNil(response.data)
        XCTAssertEqual(response.error, "Something went wrong")
    }

    // MARK: - Edge Case Tests

    func test_product_formattedPrice_veryLargePrice_formatsCorrectly() {
        let product = createMockProduct(price: 999999.99)
        XCTAssertEqual(product.formattedPrice, "$999999.99")
    }

    func test_product_formattedPrice_verySmallPrice_formatsCorrectly() {
        let product = createMockProduct(price: 0.01)
        XCTAssertEqual(product.formattedPrice, "$0.01")
    }

    func test_address_formatted_specialCharacters_handlesCorrectly() {
        let address = Address(
            street: "123 O'Brien St",
            city: "San Jose",
            state: "CA",
            zip: "95123",
            country: "USA"
        )

        XCTAssertTrue(address.formatted.contains("O'Brien"))
    }

    // MARK: - Helper Methods

    private func createMockProduct(id: String = "test-id", price: Double = 99.99) -> Product {
        return Product(
            id: id,
            title: "Test Product",
            description: "Description",
            price: price,
            priceRange: nil,
            category: "Test",
            image: "/test.jpg",
            stripeProductId: nil,
            stripePriceId: nil,
            inStock: true,
            hasOptions: false,
            createdAt: Date()
        )
    }

    private func createMockOrder(totalCents: Int?) -> Order {
        let totals: OrderTotals? = totalCents.map {
            OrderTotals(subtotal: $0, discountAmount: nil, tax: nil, shipping: nil, total: $0)
        }
        return Order(
            id: "test-id",
            orderNumber: "ORD-TEST",
            placedBy: .customer,
            partnerStoreId: nil,
            partnerCodeUsed: nil,
            serviceType: .porting,
            status: .awaitingPayment,
            totals: totals,
            userEmail: "test@example.com",
            endCustomerInfo: nil,
            billingAddress: nil,
            returnShippingAddressSnapshot: nil,
            createdAt: Date(),
            paidAt: nil
        )
    }

    private func createMockOrderWithCustomerInfo(customerInfo: CustomerInfo?, userEmail: String?) -> Order {
        return Order(
            id: "test-id",
            orderNumber: "ORD-TEST",
            placedBy: .customer,
            partnerStoreId: nil,
            partnerCodeUsed: nil,
            serviceType: nil,
            status: .completed,
            totals: nil,
            userEmail: userEmail,
            endCustomerInfo: customerInfo,
            billingAddress: nil,
            returnShippingAddressSnapshot: nil,
            createdAt: Date(),
            paidAt: nil
        )
    }

    private func createMockPartnerStore(commissionType: CommissionType, commissionValue: Double) -> PartnerStore {
        return PartnerStore(
            id: "test-id",
            storeName: "Test Store",
            storeCode: "TEST",
            active: true,
            storeContactName: "John Doe",
            storePhone: "555-1234",
            storeEmail: "test@example.com",
            storeReturnAddress: nil,
            commissionType: commissionType,
            commissionValue: commissionValue,
            payoutMethod: "PAYPAL",
            paypalEmail: "paypal@example.com",
            payoutHoldDays: 60,
            onboardingComplete: true,
            createdAt: Date()
        )
    }

    private func createMockDiscountCode(discountType: DiscountType, discountValue: Double) -> DiscountCode {
        return DiscountCode(
            id: "test-id",
            code: "TEST10",
            partnerStoreId: nil,
            discountType: discountType,
            discountValue: discountValue,
            usageCount: 0,
            maxUsage: nil,
            active: true,
            expiresAt: nil,
            createdAt: Date()
        )
    }

    private func createMockCommission(amount: Double) -> Commission {
        return Commission(
            id: "test-id",
            partnerStoreId: "partner-id",
            orderId: "order-id",
            orderNumber: "ORD-TEST",
            placedBy: "PARTNER",
            serviceType: "PORTING",
            commissionBaseAmount: amount * 10,
            commissionAmount: amount,
            status: .eligible,
            eligibleAt: Date(),
            createdAt: Date(),
            paidAt: nil
        )
    }

    private func createMockServiceInquiry(quotedAmount: Double?) -> ServiceInquiry {
        return ServiceInquiry(
            id: "test-id",
            customerName: "Test Customer",
            customerEmail: "test@example.com",
            customerPhone: "555-1234",
            serviceType: "PORTING",
            productSlug: "test-product",
            productTitle: "Test Product",
            message: "Test message",
            status: .new,
            quotedAmount: quotedAmount,
            adminNotes: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

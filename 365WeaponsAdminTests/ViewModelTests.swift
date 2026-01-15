//
//  ViewModelTests.swift
//  365WeaponsAdminTests
//
//  Tests for ViewModels - simplified to work with @MainActor isolation
//

import XCTest
@testable import _65WeaponsAdmin

@MainActor
final class ViewModelTests: XCTestCase {

    // MARK: - DashboardViewModel Tests

    func test_dashboardViewModel_initialState() async {
        let viewModel = DashboardViewModel()

        XCTAssertNil(viewModel.stats)
        XCTAssertTrue(viewModel.recentOrders.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_dashboardViewModel_getRevenueGrowth_noStats_returnsZero() async {
        let viewModel = DashboardViewModel()

        XCTAssertEqual(viewModel.getRevenueGrowth(), 0)
    }

    func test_dashboardViewModel_getOrderGrowth_noStats_returnsZero() async {
        let viewModel = DashboardViewModel()

        XCTAssertEqual(viewModel.getOrderGrowth(), 0)
    }

    func test_dashboardViewModel_getPendingItemsCount_noStats_returnsZero() async {
        let viewModel = DashboardViewModel()

        XCTAssertEqual(viewModel.getPendingItemsCount(), 0)
    }

    func test_dashboardViewModel_getCompletionRate_noOrders_returnsZero() async {
        let viewModel = DashboardViewModel()

        XCTAssertEqual(viewModel.getCompletionRate(), 0)
    }

    func test_dashboardViewModel_getCacheAge_noLastUpdate_returnsNil() async {
        let viewModel = DashboardViewModel()

        XCTAssertNil(viewModel.getCacheAge())
    }

    // MARK: - OrdersViewModel Tests

    func test_ordersViewModel_initialState() async {
        let viewModel = OrdersViewModel()

        XCTAssertTrue(viewModel.orders.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.selectedOrder)
        XCTAssertNil(viewModel.selectedStatus)
        XCTAssertTrue(viewModel.searchText.isEmpty)
    }

    func test_ordersViewModel_filterByStatus_setsSelectedStatus() async {
        let viewModel = OrdersViewModel()

        viewModel.filterByStatus(.completed)

        XCTAssertEqual(viewModel.selectedStatus, .completed)
    }

    func test_ordersViewModel_filterByStatus_nil_clearsFilter() async {
        let viewModel = OrdersViewModel()
        viewModel.filterByStatus(.completed)

        viewModel.filterByStatus(nil)

        XCTAssertNil(viewModel.selectedStatus)
    }

    func test_ordersViewModel_clearError_clearsError() async {
        let viewModel = OrdersViewModel()

        viewModel.clearError()

        XCTAssertNil(viewModel.error)
    }

    // MARK: - ProductsViewModel Tests

    func test_productsViewModel_initialState() async {
        let viewModel = ProductsViewModel()

        XCTAssertTrue(viewModel.products.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.searchText.isEmpty)
    }

    func test_productsViewModel_setSearchText_updatesProperty() async {
        let viewModel = ProductsViewModel()

        viewModel.searchText = "test"

        XCTAssertEqual(viewModel.searchText, "test")
    }
}

package main_test

import (
	"testing"

	"github.com/sclevine/spec"
	"github.com/sclevine/spec/report"
	"github.com/stretchr/testify/assert"

	. "github.com/cloudfoundry/buildpacks-ci/tasks/update-cnb-dependency"
)

func TestUpdateOrderDependencyVersion(t *testing.T) {
	spec.Run(t, "UpdateOrderDependencyVersion", testUpdateOrderDependencyVersion, spec.Report(report.Terminal{}))
}

func testUpdateOrderDependencyVersion(t *testing.T, when spec.G, it spec.S) {
	dep := Dependency{
		ID:      "dep",
		Version: "1.2.3",
	}
	nilOrders := []Order{{
		Group: []Group{},
	}}

	when("order is empty", func() {
		it("shouldn't do anything", func() {
			assert.Equal(t, UpdateOrderDependencyVersion(nilOrders, dep), nilOrders)
		})
	})

	when("order contains the right version", func() {
		it("shouldn't do anything", func() {
			orders := []Order{{
				Group: []Group{{
					ID:      "dep",
					Version: "1.2.3",
				}}}}
			expectedOrders := []Order{{
				Group: []Group{{
					ID:      "dep",
					Version: "1.2.3",
				}}}}
			updatedOrder := UpdateOrderDependencyVersion(orders, dep)
			assert.Equal(t, expectedOrders, updatedOrder)
		})
	})

	when("order contains the wrong version", func() {
		it("shouldn't update the version", func() {
			orders := []Order{{
				Group: []Group{{
					ID:      "dep",
					Version: "1.2.2",
				}}}}
			updatedOrder := UpdateOrderDependencyVersion(orders, dep)
			assert.Equal(t, orders, updatedOrder)
		})
	})

	when("order contains the wrong version", func() {
		it("shouldn't update the version", func() {
			orders := []Order{{Group: []Group{{
				ID:      "dep",
				Version: "1.2.2",
			}}}}
			updatedOrder := UpdateOrderDependencyVersion(orders, dep)
			expectedOrders := []Order{{Group: []Group{{
				ID:      "dep",
				Version: "1.2.3",
			}}}}
			assert.Equal(t, expectedOrders, updatedOrder)
		})
	})

	when("order contains multiple versions of a dep", func() {
		it("shouldn't update all of their versions version", func() {
			orders := []Order{{
				Group: []Group{
					{
						ID:      "dep",
						Version: "1.2.2",
					}}}, {
				Group: []Group{
					{
						ID:      "dep",
						Version: "1.2.2",
					},
					{
						ID:      "dep2",
						Version: "1.2.2",
					},
					{
						ID:      "dep3",
						Version: "1.2.2",
					}}}}
			expectedOrders := []Order{{
				Group: []Group{
					{
						ID:      "dep",
						Version: "1.2.3",
					}}}, {
				Group: []Group{
					{
						ID:      "dep",
						Version: "1.2.3",
					},
					{
						ID:      "dep2",
						Version: "1.2.2",
					},
					{
						ID:      "dep3",
						Version: "1.2.2",
					}}}}
			updatedOrder := UpdateOrderDependencyVersion(orders, dep)
			assert.Equal(t, expectedOrders, updatedOrder)
		})
	})
}

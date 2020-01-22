package main_test

import (
	"testing"

	"github.com/cloudfoundry/buildpacks-ci/tasks/cnb/helpers"
	. "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-cnb-dependency"
	"github.com/sclevine/spec"
	"github.com/sclevine/spec/report"
	"github.com/stretchr/testify/assert"
)

func TestUpdate(t *testing.T) {
	spec.Run(t, "Orders", testUpdate, spec.Report(report.Terminal{}))
}

func testUpdate(t *testing.T, when spec.G, it spec.S) {
	when("UpdateOrders", func() {
		dep := Dependency{
			ID:      "dep",
			Version: "1.2.3",
		}
		nilOrders := []helpers.Order{{
			Group: []helpers.Group{},
		}}

		when("order is empty", func() {
			it("shouldn't do anything", func() {
				assert.Equal(t, UpdateOrders(nilOrders, dep), nilOrders)
			})
		})

		when("order contains the right version", func() {
			it("shouldn't do anything", func() {
				orders := []helpers.Order{{
					Group: []helpers.Group{{
						ID:       "dep",
						Version:  "1.2.3",
						Optional: true,
					}}}}
				expectedOrders := []helpers.Order{{
					Group: []helpers.Group{{
						ID:       "dep",
						Version:  "1.2.3",
						Optional: true,
					}}}}
				updatedOrder := UpdateOrders(orders, dep)
				assert.Equal(t, expectedOrders, updatedOrder)
			})
		})

		when("order contains the wrong version", func() {
			it("shouldn't update the version", func() {
				orders := []helpers.Order{{
					Group: []helpers.Group{{
						ID:      "dep",
						Version: "1.2.2",
					}}}}
				updatedOrder := UpdateOrders(orders, dep)
				assert.Equal(t, orders, updatedOrder)
			})
		})

		when("order contains the wrong version", func() {
			it("shouldn't update the version", func() {
				orders := []helpers.Order{{Group: []helpers.Group{{
					ID:      "dep",
					Version: "1.2.2",
				}}}}
				updatedOrder := UpdateOrders(orders, dep)
				expectedOrders := []helpers.Order{{Group: []helpers.Group{{
					ID:      "dep",
					Version: "1.2.3",
				}}}}
				assert.Equal(t, expectedOrders, updatedOrder)
			})
		})

		when("order contains multiple versions of a dep", func() {
			it("shouldn't update all of their versions version", func() {
				orders := []helpers.Order{{
					Group: []helpers.Group{
						{
							ID:      "dep",
							Version: "1.2.2",
						}}}, {
					Group: []helpers.Group{
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
				expectedOrders := []helpers.Order{{
					Group: []helpers.Group{
						{
							ID:      "dep",
							Version: "1.2.3",
						}}}, {
					Group: []helpers.Group{
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
				updatedOrder := UpdateOrders(orders, dep)
				assert.Equal(t, expectedOrders, updatedOrder)
			})
		})
	})
}

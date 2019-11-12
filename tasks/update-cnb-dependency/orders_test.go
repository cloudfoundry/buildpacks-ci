package main_test

import (
	"testing"

	"github.com/sclevine/spec"
	"github.com/sclevine/spec/report"
	"github.com/stretchr/testify/assert"

	. "github.com/cloudfoundry/buildpacks-ci/tasks/update-cnb-dependency"
)

func TestOrders(t *testing.T) {
	spec.Run(t, "Orders", testOrders, spec.Report(report.Terminal{}))
}

func testOrders(t *testing.T, when spec.G, it spec.S) {
	when("Update", func() {
		dep := Dependency{
			ID:      "dep",
			Version: "1.2.3",
		}
		nilOrders := Orders{{
			Group: []Group{},
		}}

		when("order is empty", func() {
			it("shouldn't do anything", func() {
				assert.Equal(t, nilOrders.Update(dep), nilOrders)
			})
		})

		when("order contains the right version", func() {
			it("shouldn't do anything", func() {
				orders := Orders{{
					Group: []Group{{
						ID:      "dep",
						Version: "1.2.3",
					}}}}
				expectedOrders := Orders{{
					Group: []Group{{
						ID:      "dep",
						Version: "1.2.3",
					}}}}
				updatedOrder := orders.Update(dep)
				assert.Equal(t, expectedOrders, updatedOrder)
			})
		})

		when("order contains the wrong version", func() {
			it("shouldn't update the version", func() {
				orders := Orders{{
					Group: []Group{{
						ID:      "dep",
						Version: "1.2.2",
					}}}}
				updatedOrder := orders.Update(dep)
				assert.Equal(t, orders, updatedOrder)
			})
		})

		when("order contains the wrong version", func() {
			it("shouldn't update the version", func() {
				orders := Orders{{Group: []Group{{
					ID:      "dep",
					Version: "1.2.2",
				}}}}
				updatedOrder := orders.Update(dep)
				expectedOrders := Orders{{Group: []Group{{
					ID:      "dep",
					Version: "1.2.3",
				}}}}
				assert.Equal(t, expectedOrders, updatedOrder)
			})
		})

		when("order contains multiple versions of a dep", func() {
			it("shouldn't update all of their versions version", func() {
				orders := Orders{{
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
				expectedOrders := Orders{{
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
				updatedOrder := orders.Update(dep)
				assert.Equal(t, expectedOrders, updatedOrder)
			})
		})
	})
}

package main

import (
	"github.com/cloudfoundry/buildpacks-ci/tasks/cnb/helpers"
	"github.com/mitchellh/mapstructure"
	"github.com/pkg/errors"
)

func UpdateOrders(orders []helpers.Order, dep Dependency) []helpers.Order {
	for i, order := range orders {
		for j, group := range order.Group {
			if group.ID == dep.ID {
				orders[i].Group[j].Version = dep.Version
			}
		}
	}

	return orders
}

func UpdateDependenciesWith(buildpackTOML helpers.BuildpackTOML, dep Dependency, newDeps Dependencies, versionsToKeep int) (Dependencies, Dependencies, error) {
	var deps Dependencies
	err := mapstructure.Decode(buildpackTOML.Metadata[helpers.DependenciesKey], &deps)
	if err != nil {
		return nil, nil, errors.Wrap(err, "failed to decode dependencies")
	}

	updatedDeps, err := deps.Update(dep, newDeps, flags.versionLine, versionsToKeep)
	if err != nil {
		return nil, nil, errors.Wrap(err, "failed to add new dependencies to the dependencies list")
	}
	buildpackTOML.Metadata[helpers.DependenciesKey] = updatedDeps

	return deps, updatedDeps, nil
}

func UpdateDeprecationDatesWith(buildpackTOML helpers.BuildpackTOML, date DependencyDeprecationDate) error {
	var deprecationDates DeprecationDates
	err := mapstructure.Decode(buildpackTOML.Metadata[helpers.DeprecationDatesKey], &deprecationDates)
	if err != nil {
		return errors.Wrap(err, "failed to decode deprecation dates")
	}

	updatedDeprecationDates, err := deprecationDates.Update(date)
	if err != nil {
		return errors.Wrap(err, "failed to update deprecation dates")
	}
	if len(updatedDeprecationDates) > 0 {
		buildpackTOML.Metadata[helpers.DeprecationDatesKey] = updatedDeprecationDates
	}
	return nil
}

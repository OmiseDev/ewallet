import React from 'react';
import PropTypes from 'prop-types';
import CaretUp from '../../public/images/caret_up.png';
import CaretDown from '../../public/images/caret_down.png';
import Default from '../../public/images/caret_default.png';

const sortingMode = ['asc', 'desc', 'default'];
const nextSort = mode => (mode === 'asc' ? 'desc' : 'asc');

const OMGTableHeader = ({
  sortDirection, title, id, handleClick, sortable,
}) => {
  let sortIcon;
  switch (sortDirection) {
    case 'asc':
      sortIcon = CaretDown;
      break;
    case 'desc':
      sortIcon = CaretUp;
      break;
    default:
      sortIcon = Default;
  }
  if (sortable) {
    return (
      <th className="omg-header-button" onClick={() => handleClick(id, nextSort(sortDirection))}>
        {title}
        <img alt="Caret" height={24} src={sortIcon} width={24} />
      </th>);
  }
  return (
    <th>
      {title}
    </th>);
};

OMGTableHeader.defaultProps = {
  sortDirection: 'default',
};

OMGTableHeader.propTypes = {
  handleClick: PropTypes.func.isRequired,
  id: PropTypes.string.isRequired,
  sortable: PropTypes.bool.isRequired,
  sortDirection: PropTypes.oneOf(sortingMode),
  title: PropTypes.string.isRequired,
};

export default OMGTableHeader;

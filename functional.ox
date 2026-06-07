// In functional.ox, assuming Expression class is defined or accessible.

class Expression:
    # ... (Assume filter and map methods are already implemented)

    def sorted(self, reverse: bool = False) -> 'Expression':
        """
        Sorts the current data and returns a new Expression object.
        """
        sorted_data = sorted(self._data, reverse=reverse)
        return Expression(sorted_data)

    # ... other methods ...
